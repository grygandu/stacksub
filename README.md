 StackSub

**StackSub** is a decentralized subscription protocol built on the Stacks blockchain. It enables service providers to offer subscription plans and users to subscribe using STX payments with automatic recurring payments.

 Features

- Create subscription plans with:
  - Fee (micro-STX)
  - Payment interval (in blocks)
  - Plan metadata (description, service info)
- Allow users to subscribe to plans and make payments
- Process periodic payments (can be triggered on-chain or by off-chain automation)
- Cancel active subscriptions
- Track subscription and plan status on-chain

---
 Contract Summary

| Function | Type | Description |
|-----------|------|-------------|
| `create-plan` | public | Create a new subscription plan |
| `subscribe` | public | Subscribe to an existing plan |
| `process-payment` | public | Process a subscription payment |
| `cancel-subscription` | public | Cancel a subscription |
| `get-plan` | read-only | Get details of a subscription plan |
| `get-subscription` | read-only | Get a user’s subscription details |

---

## 📝 How It Works

1 A provider calls `create-plan` to register a plan with fee, interval, and metadata.  
2 A user calls `subscribe` to join a plan and pay the first fee.  
3 `process-payment` is called periodically to collect the fee.  
4 User can cancel anytime using `cancel-subscription`.  

---

 Example Usage

```clarity
;; Provider creates a plan
(create-plan u1000000 u144 "Basic plan - access to premium features")

;; User subscribes to plan 0
(subscribe u0)

;; Off-chain or on-chain call to process a payment
(process-payment tx-sender u0)

;; User cancels subscription
(cancel-subscription u0)
