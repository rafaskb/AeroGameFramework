# Event Guide

All events are registered to AeroServer and AeroClient. You can register, fire, and connect to them from any Aero-aware object.

## Server to Server:

Used internally in the server. Has nothing to do with clients.

| Action   | Method                               | Call From |
|----------|--------------------------------------|-----------|
| Register | `RegisterEvent(event)`               | Server    |
| Fire     | `FireEvent(event, ...)`              | Server    |
| Connect  | `ConnectEvent(event, function(...))` | Server    |

## Server to Client:

Registered and fired through the server, received by the client.

| Action   | Method                                      | Call From  |
|----------|---------------------------------------------|------------|
| Register | `RegisterClientEvent(event)`                | Server     |
| Fire     | `FireClientEvent(event, player, ...)`       | Server     |
| FireAll  | `FireAllClientsEvent(event, ...)`           | Server     |
| Connect  | `ConnectServiceEvent(event, function(...))` | **Client** |

## Client to Client (same client):

Used internally in the client. Never leaves the player's computer.

| Action   | Method                               | Call From |
|----------|--------------------------------------|-----------|
| Register | `RegisterEvent(event)`               | Client    |
| Fire     | `FireEvent(event, player, ...)`      | Client    |
| Connect  | `ConnectEvent(event, function(...))` | Client    |
