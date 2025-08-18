(define-non-fungible-token rental-property uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-property-occupied (err u103))
(define-constant err-insufficient-payment (err u104))
(define-constant err-rental-expired (err u105))
(define-constant err-rental-active (err u106))
(define-constant err-already-checked-in (err u107))
(define-constant err-not-checked-in (err u108))
(define-constant err-invalid-duration (err u109))
(define-constant err-deposit-not-returned (err u110))
(define-constant err-invalid-rating (err u111))
(define-constant err-already-rated (err u112))
(define-constant err-cannot-rate-self (err u113))

(define-data-var next-property-id uint u1)
(define-data-var platform-fee-rate uint u250)

(define-map property-listings
  uint
  {
    landlord: principal,
    rent-per-block: uint,
    deposit-amount: uint,
    max-duration: uint,
    available: bool,
    property-address: (string-ascii 256),
    description: (string-ascii 512)
  }
)

(define-map active-rentals
  uint
  {
    tenant: principal,
    start-block: uint,
    end-block: uint,
    deposit-paid: uint,
    rent-paid: uint,
    checked-in: bool,
    deposit-returned: bool
  }
)

(define-map user-rental-history
  principal
  (list 50 uint)
)

(define-map property-earnings
  uint
  uint
)

(define-map tenant-ratings
  principal
  {
    total-score: uint,
    total-ratings: uint,
    ratings-list: (list 20 uint)
  }
)

(define-map rental-ratings
  {property-id: uint, tenant: principal}
  uint
)

(define-read-only (get-property-listing (property-id uint))
  (map-get? property-listings property-id)
)

(define-read-only (get-active-rental (property-id uint))
  (map-get? active-rentals property-id)
)

(define-read-only (get-next-property-id)
  (var-get next-property-id)
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (get-user-rental-history (user principal))
  (default-to (list) (map-get? user-rental-history user))
)

(define-read-only (get-property-earnings (property-id uint))
  (default-to u0 (map-get? property-earnings property-id))
)

(define-read-only (get-tenant-rating-stats (tenant principal))
  (match (map-get? tenant-ratings tenant)
    rating-data
    (ok {
      average-rating: (if (> (get total-ratings rating-data) u0)
        (/ (get total-score rating-data) (get total-ratings rating-data))
        u0
      ),
      total-ratings: (get total-ratings rating-data),
      ratings: (get ratings-list rating-data)
    })
    (ok {
      average-rating: u0,
      total-ratings: u0,
      ratings: (list)
    })
  )
)

(define-read-only (get-rental-rating (property-id uint) (tenant principal))
  (map-get? rental-ratings {property-id: property-id, tenant: tenant})
)

(define-read-only (has-rated-rental (property-id uint) (landlord principal) (tenant principal))
  (is-some (map-get? rental-ratings {property-id: property-id, tenant: tenant}))
)

(define-read-only (is-rental-active (property-id uint))
  (match (map-get? active-rentals property-id)
    rental (< stacks-block-height (get end-block rental))
    false
  )
)

(define-read-only (is-rental-expired (property-id uint))
  (match (map-get? active-rentals property-id)
    rental (>= stacks-block-height (get end-block rental))
    true
  )
)

(define-read-only (get-rental-time-remaining (property-id uint))
  (match (map-get? active-rentals property-id)
    rental 
    (if (< stacks-block-height (get end-block rental))
      (ok (- (get end-block rental) stacks-block-height))
      (ok u0)
    )
    (err err-listing-not-found)
  )
)

(define-read-only (calculate-total-cost (property-id uint) (duration uint))
  (match (map-get? property-listings property-id)
    listing
    (let
      (
        (rent-cost (* (get rent-per-block listing) duration))
        (deposit (get deposit-amount listing))
        (platform-fee (/ (* rent-cost (var-get platform-fee-rate)) u10000))
      )
      (ok {
        rent: rent-cost,
        deposit: deposit,
        platform-fee: platform-fee,
        total: (+ rent-cost deposit platform-fee)
      })
    )
    (err err-listing-not-found)
  )
)

(define-public (list-property 
  (rent-per-block uint)
  (deposit-amount uint)
  (max-duration uint)
  (property-address (string-ascii 256))
  (description (string-ascii 512))
)
  (let
    (
      (property-id (var-get next-property-id))
    )
    (asserts! (> max-duration u0) err-invalid-duration)
    (asserts! (> rent-per-block u0) err-insufficient-payment)
    
    (map-set property-listings property-id
      {
        landlord: tx-sender,
        rent-per-block: rent-per-block,
        deposit-amount: deposit-amount,
        max-duration: max-duration,
        available: true,
        property-address: property-address,
        description: description
      }
    )
    
    (var-set next-property-id (+ property-id u1))
    (ok property-id)
  )
)

(define-public (rent-property (property-id uint) (duration uint))
  (let
    (
      (listing (unwrap! (map-get? property-listings property-id) err-listing-not-found))
      (cost-info (unwrap! (calculate-total-cost property-id duration) err-listing-not-found))
      (end-block (+ stacks-block-height duration))
    )
    (asserts! (get available listing) err-property-occupied)
    (asserts! (<= duration (get max-duration listing)) err-invalid-duration)
    (asserts! (not (is-rental-active property-id)) err-property-occupied)
    
    (try! (stx-transfer? (get total cost-info) tx-sender (as-contract tx-sender)))
    
    (try! (nft-mint? rental-property property-id tx-sender))
    
    (map-set active-rentals property-id
      {
        tenant: tx-sender,
        start-block: stacks-block-height,
        end-block: end-block,
        deposit-paid: (get deposit cost-info),
        rent-paid: (get rent cost-info),
        checked-in: false,
        deposit-returned: false
      }
    )
    
    (map-set property-listings property-id
      (merge listing { available: false })
    )
    
    (map-set user-rental-history tx-sender
      (unwrap! (as-max-len? 
        (append (get-user-rental-history tx-sender) property-id) 
        u50
      ) (ok true))
    )
    
    (map-set property-earnings property-id
      (+ (get-property-earnings property-id) (get rent cost-info))
    )
    
    (ok true)
  )
)

(define-public (check-in (property-id uint))
  (let
    (
      (rental (unwrap! (map-get? active-rentals property-id) err-listing-not-found))
    )
    (asserts! (is-eq tx-sender (get tenant rental)) err-not-token-owner)
    (asserts! (is-rental-active property-id) err-rental-expired)
    (asserts! (not (get checked-in rental)) err-already-checked-in)
    
    (map-set active-rentals property-id
      (merge rental { checked-in: true })
    )
    
    (ok true)
  )
)

(define-public (check-out (property-id uint))
  (let
    (
      (rental (unwrap! (map-get? active-rentals property-id) err-listing-not-found))
      (listing (unwrap! (map-get? property-listings property-id) err-listing-not-found))
    )
    (asserts! (is-eq tx-sender (get tenant rental)) err-not-token-owner)
    (asserts! (get checked-in rental) err-not-checked-in)
    
    (if (and (not (get deposit-returned rental)) (> (get deposit-paid rental) u0))
      (begin
        (try! (as-contract (stx-transfer? (get deposit-paid rental) tx-sender (get tenant rental))))
        (map-set active-rentals property-id
          (merge rental { deposit-returned: true })
        )
      )
      true
    )
    
    (try! (nft-burn? rental-property property-id (get tenant rental)))
    
    (map-delete active-rentals property-id)
    
    (map-set property-listings property-id
      (merge listing { available: true })
    )
    
    (ok true)
  )
)

(define-public (extend-rental (property-id uint) (additional-duration uint))
  (let
    (
      (rental (unwrap! (map-get? active-rentals property-id) err-listing-not-found))
      (listing (unwrap! (map-get? property-listings property-id) err-listing-not-found))
      (additional-cost (* (get rent-per-block listing) additional-duration))
      (platform-fee (/ (* additional-cost (var-get platform-fee-rate)) u10000))
      (total-cost (+ additional-cost platform-fee))
      (new-end-block (+ (get end-block rental) additional-duration))
    )
    (asserts! (is-eq tx-sender (get tenant rental)) err-not-token-owner)
    (asserts! (is-rental-active property-id) err-rental-expired)
    (asserts! (<= additional-duration (get max-duration listing)) err-invalid-duration)
    
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    
    (map-set active-rentals property-id
      (merge rental { 
        end-block: new-end-block,
        rent-paid: (+ (get rent-paid rental) additional-cost)
      })
    )
    
    (map-set property-earnings property-id
      (+ (get-property-earnings property-id) additional-cost)
    )
    
    (ok true)
  )
)

(define-public (emergency-eviction (property-id uint))
  (let
    (
      (listing (unwrap! (map-get? property-listings property-id) err-listing-not-found))
      (rental (unwrap! (map-get? active-rentals property-id) err-listing-not-found))
    )
    (asserts! (is-eq tx-sender (get landlord listing)) err-owner-only)
    (asserts! (is-rental-active property-id) err-rental-expired)
    
    (try! (nft-burn? rental-property property-id (get tenant rental)))
    
    (map-delete active-rentals property-id)
    
    (map-set property-listings property-id
      (merge listing { available: true })
    )
    
    (ok true)
  )
)

(define-public (withdraw-earnings (property-id uint))
  (let
    (
      (listing (unwrap! (map-get? property-listings property-id) err-listing-not-found))
      (earnings (get-property-earnings property-id))
    )
    (asserts! (is-eq tx-sender (get landlord listing)) err-owner-only)
    (asserts! (> earnings u0) err-insufficient-payment)
    
    (try! (as-contract (stx-transfer? earnings tx-sender (get landlord listing))))
    
    (map-set property-earnings property-id u0)
    
    (ok earnings)
  )
)

(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-duration)
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

(define-public (auto-expire-rental (property-id uint))
  (let
    (
      (rental (unwrap! (map-get? active-rentals property-id) err-listing-not-found))
      (listing (unwrap! (map-get? property-listings property-id) err-listing-not-found))
    )
    (asserts! (is-rental-expired property-id) err-rental-active)
    
    (try! (nft-burn? rental-property property-id (get tenant rental)))
    
    (map-delete active-rentals property-id)
    
    (map-set property-listings property-id
      (merge listing { available: true })
    )
    
    (ok true)
  )
)

(define-public (rate-tenant (property-id uint) (tenant principal) (rating uint))
  (let
    (
      (listing (unwrap! (map-get? property-listings property-id) err-listing-not-found))
      (existing-rating-data (default-to 
        {total-score: u0, total-ratings: u0, ratings-list: (list)}
        (map-get? tenant-ratings tenant)
      ))
      (rating-key {property-id: property-id, tenant: tenant})
    )
    (asserts! (is-eq tx-sender (get landlord listing)) err-owner-only)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    (asserts! (not (is-eq tx-sender tenant)) err-cannot-rate-self)
    (asserts! (not (has-rated-rental property-id tx-sender tenant)) err-already-rated)
    
    (map-set rental-ratings rating-key rating)
    
    (map-set tenant-ratings tenant
      {
        total-score: (+ (get total-score existing-rating-data) rating),
        total-ratings: (+ (get total-ratings existing-rating-data) u1),
        ratings-list: (unwrap! (as-max-len? 
          (append (get ratings-list existing-rating-data) rating) 
          u20
        ) (ok true))
      }
    )
    
    (ok true)
  )
)
