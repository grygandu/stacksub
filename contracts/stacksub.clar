;; --------------------------------------------------
;; Contract: stackaccess-plus
;; Description: Enhanced subscription paywall using STX
;; License: MIT
;; --------------------------------------------------

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_PAYMENT (err u101))
(define-constant ERR_ALREADY_SUBSCRIBED (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_SUBSCRIPTIONS_PAUSED (err u104))
(define-constant ERR_NOT_FOUND (err u105))

;; === Admin Variables ===
(define-data-var contract-owner principal tx-sender)
(define-data-var subscription-price uint u5000000) ;; 5 STX
(define-data-var subscription-duration uint u4320) ;; ~30 days (in blocks)
(define-data-var collected-funds uint u0)
(define-data-var subscriptions-paused bool false)

;; === Subscriptions Map ===
(define-map subscriptions
  {subscriber: principal}
  {
    expires: uint,
    lifetime: bool
  }
)

;; === Admin: Set price ===
(define-public (set-subscription-price (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set subscription-price price)
    (ok true)
  )
)

;; === Admin: Set duration ===
(define-public (set-subscription-duration (duration uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set subscription-duration duration)
    (ok true)
  )
)

;; === Admin: Pause/Unpause subscriptions ===
(define-public (toggle-subscription-pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set subscriptions-paused (not (var-get subscriptions-paused)))
    (ok (var-get subscriptions-paused))
  )
)

;; === Admin: Grant lifetime access ===
(define-public (grant-lifetime-subscription (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set subscriptions {subscriber: user} {expires: u0, lifetime: true})
    (ok true)
  )
)

;; === Admin: Cancel user's subscription ===
(define-public (cancel-subscription (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-delete subscriptions {subscriber: user})
    (ok true)
  )
)

;; === Admin: Transfer ownership ===
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; === Subscribe for self ===
(define-public (subscribe)
  (subscribe-for tx-sender)
)

;; === Subscribe for someone else ===
(define-public (subscribe-for (user principal))
  (begin
    (asserts! (not (var-get subscriptions-paused)) ERR_SUBSCRIPTIONS_PAUSED)

    (let (
      (price (var-get subscription-price))
      (duration (var-get subscription-duration))
      (current-block stacks-block-height)
      (existing-sub (map-get? subscriptions {subscriber: user}))
    )
      ;; Check if user already has lifetime subscription
      (match existing-sub
        subscription 
          (if (get lifetime subscription)
            ERR_ALREADY_SUBSCRIBED ;; Can't extend lifetime
            (let (
              (expires (get expires subscription))
              (new-expiry (if (> expires current-block)
                          (+ expires duration)
                          (+ current-block duration)))
            )
              ;; Transfer payment and update subscription
              (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
              (map-set subscriptions {subscriber: user} {expires: new-expiry, lifetime: false})
              (var-set collected-funds (+ (var-get collected-funds) price))
              (ok new-expiry)
            )
          )
        ;; No existing subscription - create new one
        (let ((new-expiry (+ current-block duration)))
          (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
          (map-set subscriptions {subscriber: user} {expires: new-expiry, lifetime: false})
          (var-set collected-funds (+ (var-get collected-funds) price))
          (ok new-expiry)
        )
      )
    )
  )
)

;; === Read-only: Check if user has access ===
(define-read-only (check-access (user principal))
  (match (map-get? subscriptions {subscriber: user})
    sub
      (ok (or (get lifetime sub)
              (>= (get expires sub) stacks-block-height)))
    (ok false)
  )
)

;; === Read-only: Get expiry info ===
(define-read-only (get-subscription (user principal))
  (match (map-get? subscriptions {subscriber: user})
    sub (ok sub)
    (ok {expires: u0, lifetime: false})
  )
)

;; === Admin: Withdraw funds ===
(define-public (withdraw-funds (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= amount (var-get collected-funds)) ERR_INSUFFICIENT_FUNDS)
    (var-set collected-funds (- (var-get collected-funds) amount))
    (stx-transfer? amount (as-contract tx-sender) recipient)
  )
)

;; === Read-only: View balance ===
(define-read-only (get-collected-funds)
  (ok (var-get collected-funds))
)

;; === Read-only: Get subscription status ===
(define-read-only (is-subscriptions-paused)
  (ok (var-get subscriptions-paused))
)

;; === Read-only: Get contract owner ===
(define-read-only (get-owner)
  (ok (var-get contract-owner))
)
