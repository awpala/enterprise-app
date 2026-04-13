using EA.Domain.Interfaces;
using MassTransit;

namespace EA.Infrastructure.Messaging;

/// <summary>
/// MassTransit send/publish filter that stamps the current authenticated user's
/// identity onto every outbound message as transport headers. Downstream
/// consumers (including the Python data engine) read these headers to attribute
/// a command back to the originating HTTP caller without expanding the message
/// body contract.
/// </summary>
/// <remarks>
/// <para>
/// Registered as an open generic against <see cref="SendContext{T}"/> — MassTransit v8
/// dispatches the typed variant for both <c>Publish</c> and <c>Send</c> pipelines
/// when wired via <c>ConfigureSend</c> / <c>ConfigurePublish</c> with
/// <c>UseSendFilter(typeof(UserContextPublishFilter&lt;&gt;), context)</c>.
/// </para>
/// <para>
/// The filter depends on the request-scoped <see cref="ICurrentUser"/>; MassTransit
/// resolves it from the message-scoped container, so the HTTP request's principal
/// is reflected on every message published inside that request.
/// </para>
/// <para>
/// Non-HTTP publish paths (seeder, background services) will see
/// <see cref="ICurrentUser.IsAuthenticated"/> as <c>false</c> and are silently
/// skipped — absence of headers is the "system / background" signal for
/// consumers.
/// </para>
/// </remarks>
public sealed class UserContextPublishFilter<T>(ICurrentUser currentUser)
    : IFilter<SendContext<T>>, IFilter<PublishContext<T>>
    where T : class
{
    /// <summary>
    /// Header name carrying the Entra object identifier of the caller.
    /// </summary>
    public const string UserOidHeader = "x-user-oid";

    /// <summary>
    /// Header name carrying the Entra tenant identifier of the caller.
    /// </summary>
    public const string UserTidHeader = "x-user-tid";

    /// <summary>
    /// Header name carrying the upstream identity provider of the caller.
    /// </summary>
    public const string UserIdpHeader = "x-user-idp";

    /// <summary>
    /// Header name carrying the caller's display name.
    /// </summary>
    public const string UserNameHeader = "x-user-name";

    /// <summary>
    /// Header name carrying the caller's email address.
    /// </summary>
    public const string UserEmailHeader = "x-user-email";

    /// <inheritdoc />
    public Task Send(SendContext<T> context, IPipe<SendContext<T>> next)
    {
        StampHeaders(context);
        return next.Send(context);
    }

    /// <inheritdoc />
    public Task Send(PublishContext<T> context, IPipe<PublishContext<T>> next)
    {
        StampHeaders(context);
        return next.Send(context);
    }

    /// <inheritdoc />
    public void Probe(ProbeContext context) => context.CreateFilterScope("user-context");

    private void StampHeaders(SendContext context)
    {
        if (!currentUser.IsAuthenticated)
        {
            return;
        }

        if (currentUser.Oid is { } oid)
        {
            context.Headers.Set(UserOidHeader, oid.ToString());
        }

        if (currentUser.Tid is { } tid)
        {
            context.Headers.Set(UserTidHeader, tid.ToString());
        }

        if (!string.IsNullOrEmpty(currentUser.Idp))
        {
            context.Headers.Set(UserIdpHeader, currentUser.Idp);
        }

        if (!string.IsNullOrEmpty(currentUser.Name))
        {
            context.Headers.Set(UserNameHeader, currentUser.Name);
        }

        if (!string.IsNullOrEmpty(currentUser.Email))
        {
            context.Headers.Set(UserEmailHeader, currentUser.Email);
        }
    }
}
