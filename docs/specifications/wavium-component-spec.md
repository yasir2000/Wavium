# Wavium Component Specification

This specification covers component packaging, loading, linking, and execution expectations.

## A Component Must

- declare its WIT interfaces
- remain portable across supported targets
- execute under runtime-managed capabilities
- avoid implicit OS dependencies

## Stability Rule

If a component change affects the public interface, update WIT, SDK generation, and the relevant tutorial or reference page together.

## Related Documentation

- [Component Model](../architecture/component-model.md)
- [Wavium Runtime Spec](wavium-runtime-spec.md)
- [Create a Component](../developers/create-component.md)