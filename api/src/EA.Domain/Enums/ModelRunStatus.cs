namespace EA.Domain.Enums;

/// <summary>
/// Represents the execution status of a model run.
/// </summary>
public enum ModelRunStatus
{
    /// <summary>The run has been requested and is awaiting processing.</summary>
    Pending = 0,

    /// <summary>The run is currently being executed.</summary>
    Running = 1,

    /// <summary>The run completed successfully.</summary>
    Completed = 2,

    /// <summary>The run failed during execution.</summary>
    Failed = 3
}
