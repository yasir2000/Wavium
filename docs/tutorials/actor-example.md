# Actor Example

This tutorial demonstrates a small actor-driven workload that uses a mailbox and supervised lifecycle.

## Prerequisites

- familiarity with the runtime and component docs
- a basic component that can receive messages
- an actor or mailbox abstraction in the runtime layer

## Focus

The example should highlight message boundaries, not shared mutable state.

## Tutorial Flow

```mermaid
flowchart TD
	Inbox[Mailbox] --> Actor[Actor]
	Actor --> State[Actor State]
	Actor --> Supervisor[Supervisor]
	Supervisor --> Recovery[Recovery]
```

1. create one actor with an explicit mailbox
2. define the message shape and processing rules
3. connect the actor to a supervisor
4. inject a few messages and observe transitions
5. verify the actor remains isolated from sibling actors

## Expected Behavior

- messages arrive in a bounded queue
- state changes occur only through message handling
- supervisor policy handles restarts or failures
- no sibling actor directly mutates the actor state

## Learning Outcome

Readers should understand how an actor receives work, transitions state, and remains isolated from sibling actors.