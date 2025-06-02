# Chuck-Stack CLI Design Philosophy

This document outlines the design methodologies and principles used in chuck-stack's nushell command-line interface.

## Command Naming Methodologies

### Standard Pattern: `<module> <action>`
The conventional approach for module-specific operations:
- **Predictability**: Users can expect consistent behavior across modules
- **Module Boundaries**: Clear separation of concerns and functionality
- **Discoverability**: Standard help patterns and command structure

### Pattern Commands: `.<action> <module>`
Commands prefixed with a dot signal cross-module functionality that breaks the normal pattern.

#### When to Use Pattern Commands
Pattern commands are appropriate when:
1. **Context-Aware Operations**: The command can intelligently determine relationships without explicit specification
2. **Cross-Module Patterns**: The same logical operation applies across different entity types
3. **Implicit Context**: The user doesn't need to specify connection details explicitly

#### Design Rationale for Dot Prefix
The dot serves as a **semantic signal** that this command operates differently:
- **Namespace Separation**: Clearly distinguishes from standard module commands
- **Context Indication**: Signals the command uses implicit context or relationships
- **Pattern Recognition**: Users learn one approach that works across modules

#### Trade-offs Considered
**Benefits:**
- Clear semantic distinction from standard commands
- Enables context-aware operations without verbose syntax
- Reduces cognitive load for relationship creation

**Concerns:**
- Non-standard CLI convention
- Learning curve for new users
- Potential namespace considerations

## Relationship Modeling Philosophy

### UUID-Based References
All entity relationships use UUIDs as the foundation for:
- **Immutable References**: Links remain valid across system changes
- **Flexible Relationships**: Any entity can reference any other entity type
- **Type Safety**: UUID validation prevents invalid references

### Append Semantics
The `.append` pattern expresses "create new record in the context of existing entity" but allows each module to implement the relationship logic that makes sense for its domain.

## Design Decision Framework

### Consistency vs. Flexibility
- **Standard commands** provide consistency and predictability
- **Pattern commands** provide flexibility for common workflows
- Both approaches coexist to serve different user needs

### Context vs. Explicitness
- Standard commands require explicit parameters
- Pattern commands leverage context to reduce verbosity
- Choice depends on whether context can be reliably inferred

### Convention vs. Innovation
- Follow established CLI patterns where they serve users well
- Innovate where conventional approaches create friction
- Signal innovation clearly (like the dot prefix) to set user expectations

## Evolution Principles

### User-Driven Design
- Command patterns emerge from real usage scenarios
- Iterate based on observed workflows and pain points
- Balance innovation with familiarity

### Semantic Clarity
- Command names should express intent, not just mechanics
- Distinguish between different types of operations clearly
- Use consistent metaphors across the interface

### Context Awareness
- Leverage available context to reduce user effort
- Make implicit relationships explicit through clear naming
- Fail gracefully when context is insufficient

## Summary

Chuck-stack's CLI design methodology balances predictable patterns with innovative approaches for common workflows. The goal is to provide both consistency for discoverability and flexibility for efficiency, using clear signals to help users understand when they're using different approaches.