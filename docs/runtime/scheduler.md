# Scheduler

Wavium uses cooperative scheduling for predictable workload control.

The scheduler is responsible for:
- task admission
- fairness and backpressure
- actor execution ordering
- deterministic progress under constrained resources

Scheduling policy must remain explicit and testable because runtime behavior is part of the platform contract.