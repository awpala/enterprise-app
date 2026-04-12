namespace EA.Domain.Enums;

/// <summary>
/// Represents the lifecycle status of a model.
/// </summary>
public enum ModelStatus
{
    /// <summary>The model is in draft state and not yet active.</summary>
    Draft = 0,

    /// <summary>The model is active and available for runs.</summary>
    Active = 1,

    /// <summary>The model has been archived (soft-deleted).</summary>
    Archived = 2
}
