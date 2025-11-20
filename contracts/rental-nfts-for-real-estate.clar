;; Rental NFTs for Real Estate with Maintenance Tracking
;; SIP-009 Compliant NFT Contract for Property Rentals

(define-non-fungible-token rental-property uint)

;; Constants
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
(define-constant err-maintenance-not-found (err u114))
(define-constant err-invalid-maintenance-status (err u115))
(define-constant err-invalid-priority (err u116))
(define-constant err-invalid-request-type (err u117))
(define-constant err-not-contractor (err u118))
(define-constant err-dispute-exists (err u119))
(define-constant err-dispute-not-found (err u120))
(define-constant err-dispute-resolved (err u121))
(define-constant err-not-dispute-party (err u122))
(define-constant err-invalid-refund-percentage (err u123))

;; Data Variables
(define-data-var next-property-id uint u1)
(define-data-var platform-fee-rate uint u250) ;; 2.5%
(define-data-var next-maintenance-id uint u1)
(define-data-var next-dispute-id uint u1)

;; Core Rental Maps
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
    average-rating: uint
  }
)

(define-map rental-ratings
  {property-id: uint, tenant: principal}
  uint
)

;; NEW FEATURE: Maintenance Tracking System
(define-map property-maintenance-requests
  uint
  {
    property-id: uint,
    landlord: principal,
    request-type: uint, ;; 1=plumbing, 2=electrical, 3=hvac, 4=structural, 5=cosmetic
    description: (string-ascii 512),
    priority: uint, ;; 1=emergency, 2=urgent, 3=normal, 4=low
    estimated-cost: uint,
    actual-cost: uint,
    status: uint, ;; 1=pending, 2=approved, 3=in-progress, 4=completed, 5=cancelled
    created-at: uint,
    completed-at: uint,
    contractor: (optional principal),
    notes: (string-ascii 256)
  }
)

(define-map property-maintenance-history
  uint
  (list 50 uint)
)

(define-map property-maintenance-costs
  uint
  uint
)

(define-map contractor-ratings
  principal
  {
    total-score: uint,
    total-jobs: uint,
    average-rating: uint
  }
)

(define-map authorized-contractors
  principal
  bool
)

(define-map rental-disputes
  uint
  {
    property-id: uint,
    raised-by: principal,
    dispute-type: uint,
    description: (string-ascii 512),
    evidence: (string-ascii 256),
    status: uint,
    created-at: uint,
    resolved-at: uint,
    resolution: (string-ascii 256),
    tenant-refund-percentage: uint,
    landlord-penalty-percentage: uint
  }
)

(define-map property-disputes
  uint
  (list 20 uint)
)

(define-map dispute-participants
  uint
  {tenant: principal, landlord: principal}
)

;; Core Read-Only Functions
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
      average-rating: (get average-rating rating-data),
      total-ratings: (get total-ratings rating-data)
    })
    (ok {
      average-rating: u0,
      total-ratings: u0
    })
  )
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

;; NEW: Maintenance System Read-Only Functions
(define-read-only (get-maintenance-request (maintenance-id uint))
  (map-get? property-maintenance-requests maintenance-id)
)

(define-read-only (get-next-maintenance-id)
  (var-get next-maintenance-id)
)

(define-read-only (get-property-maintenance-history (property-id uint))
  (default-to (list) (map-get? property-maintenance-history property-id))
)

(define-read-only (get-property-maintenance-costs (property-id uint))
  (default-to u0 (map-get? property-maintenance-costs property-id))
)

(define-read-only (get-contractor-rating (contractor principal))
  (match (map-get? contractor-ratings contractor)
    rating-data
    (ok {
      average-rating: (get average-rating rating-data),
      total-jobs: (get total-jobs rating-data)
    })
    (ok {
      average-rating: u0,
      total-jobs: u0
    })
  )
)

(define-read-only (is-authorized-contractor (contractor principal))
  (default-to false (map-get? authorized-contractors contractor))
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? rental-disputes dispute-id)
)

(define-read-only (get-property-disputes (property-id uint))
  (default-to (list) (map-get? property-disputes property-id))
)

(define-read-only (get-next-dispute-id)
  (var-get next-dispute-id)
)

(define-read-only (has-active-dispute (property-id uint))
  (let
    (
      (dispute-list (get-property-disputes property-id))
    )
    (is-some (fold check-active-dispute dispute-list none))
  )
)

(define-private (check-active-dispute (dispute-id uint) (found (optional uint)))
  (if (is-some found)
    found
    (match (map-get? rental-disputes dispute-id)
      dispute
      (if (is-eq (get status dispute) u1)
        (some dispute-id)
        none
      )
      none
    )
  )
)

;; Core Public Functions
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

;; NEW FEATURE: Maintenance System Public Functions

(define-public (create-maintenance-request
  (property-id uint)
  (request-type uint)
  (description (string-ascii 512))
  (priority uint)
  (estimated-cost uint)
)
  (let
    (
      (maintenance-id (var-get next-maintenance-id))
      (listing (unwrap! (map-get? property-listings property-id) err-listing-not-found))
    )
    (asserts! (is-eq tx-sender (get landlord listing)) err-owner-only)
    (asserts! (and (>= request-type u1) (<= request-type u5)) err-invalid-request-type)
    (asserts! (and (>= priority u1) (<= priority u4)) err-invalid-priority)
    
    (map-set property-maintenance-requests maintenance-id
      {
        property-id: property-id,
        landlord: tx-sender,
        request-type: request-type,
        description: description,
        priority: priority,
        estimated-cost: estimated-cost,
        actual-cost: u0,
        status: u1,
        created-at: stacks-block-height,
        completed-at: u0,
        contractor: none,
        notes: ""
      }
    )
    
    (map-set property-maintenance-history property-id
      (unwrap! (as-max-len? 
        (append (get-property-maintenance-history property-id) maintenance-id) 
        u50
      ) (ok maintenance-id))
    )
    
    (var-set next-maintenance-id (+ maintenance-id u1))
    (ok maintenance-id)
  )
)

(define-public (assign-contractor (maintenance-id uint) (contractor principal))
  (let
    (
      (request (unwrap! (map-get? property-maintenance-requests maintenance-id) err-maintenance-not-found))
    )
    (asserts! (is-eq tx-sender (get landlord request)) err-owner-only)
    (asserts! (is-authorized-contractor contractor) err-not-contractor)
    (asserts! (is-eq (get status request) u1) err-invalid-maintenance-status)
    
    (map-set property-maintenance-requests maintenance-id
      (merge request {
        contractor: (some contractor),
        status: u2
      })
    )
    
    (ok true)
  )
)

(define-public (start-maintenance-work (maintenance-id uint))
  (let
    (
      (request (unwrap! (map-get? property-maintenance-requests maintenance-id) err-maintenance-not-found))
    )
    (asserts! 
      (match (get contractor request)
        contractor (is-eq tx-sender contractor)
        false
      )
      err-not-contractor
    )
    (asserts! (is-eq (get status request) u2) err-invalid-maintenance-status)
    
    (map-set property-maintenance-requests maintenance-id
      (merge request { status: u3 })
    )
    
    (ok true)
  )
)

(define-public (complete-maintenance-work 
  (maintenance-id uint)
  (actual-cost uint)
  (notes (string-ascii 256))
)
  (let
    (
      (request (unwrap! (map-get? property-maintenance-requests maintenance-id) err-maintenance-not-found))
    )
    (asserts! 
      (match (get contractor request)
        contractor (is-eq tx-sender contractor)
        false
      )
      err-not-contractor
    )
    (asserts! (is-eq (get status request) u3) err-invalid-maintenance-status)
    
    (map-set property-maintenance-requests maintenance-id
      (merge request {
        actual-cost: actual-cost,
        status: u4,
        completed-at: stacks-block-height,
        notes: notes
      })
    )
    
    (map-set property-maintenance-costs (get property-id request)
      (+ (get-property-maintenance-costs (get property-id request)) actual-cost)
    )
    
    (ok true)
  )
)

(define-public (rate-contractor (maintenance-id uint) (rating uint))
  (let
    (
      (request (unwrap! (map-get? property-maintenance-requests maintenance-id) err-maintenance-not-found))
      (contractor-principal (unwrap! (get contractor request) err-not-contractor))
      (existing-rating (default-to 
        {total-score: u0, total-jobs: u0, average-rating: u0}
        (map-get? contractor-ratings contractor-principal)
      ))
    )
    (asserts! (is-eq tx-sender (get landlord request)) err-owner-only)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    (asserts! (is-eq (get status request) u4) err-invalid-maintenance-status)
    
    (let
      (
        (new-total-score (+ (get total-score existing-rating) rating))
        (new-total-jobs (+ (get total-jobs existing-rating) u1))
        (new-average (/ new-total-score new-total-jobs))
      )
      (map-set contractor-ratings contractor-principal
        {
          total-score: new-total-score,
          total-jobs: new-total-jobs,
          average-rating: new-average
        }
      )
    )
    
    (ok true)
  )
)

(define-public (authorize-contractor (contractor principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-contractors contractor true)
    (ok true)
  )
)

(define-public (revoke-contractor (contractor principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-contractors contractor false)
    (ok true)
  )
)

(define-public (cancel-maintenance-request (maintenance-id uint))
  (let
    (
      (request (unwrap! (map-get? property-maintenance-requests maintenance-id) err-maintenance-not-found))
    )
    (asserts! (is-eq tx-sender (get landlord request)) err-owner-only)
    (asserts! (< (get status request) u3) err-invalid-maintenance-status)
    
    (map-set property-maintenance-requests maintenance-id
      (merge request { status: u5 })
    )
    
    (ok true)
  )
)

(define-public (raise-dispute
  (property-id uint)
  (dispute-type uint)
  (description (string-ascii 512))
  (evidence (string-ascii 256))
)
  (let
    (
      (dispute-id (var-get next-dispute-id))
      (listing (unwrap! (map-get? property-listings property-id) err-listing-not-found))
      (rental (unwrap! (map-get? active-rentals property-id) err-listing-not-found))
    )
    (asserts! (is-rental-active property-id) err-rental-expired)
    (asserts! (not (has-active-dispute property-id)) err-dispute-exists)
    (asserts!
      (or
        (is-eq tx-sender (get tenant rental))
        (is-eq tx-sender (get landlord listing))
      )
      err-not-dispute-party
    )
    (asserts! (and (>= dispute-type u1) (<= dispute-type u5)) err-invalid-request-type)
    
    (map-set rental-disputes dispute-id
      {
        property-id: property-id,
        raised-by: tx-sender,
        dispute-type: dispute-type,
        description: description,
        evidence: evidence,
        status: u1,
        created-at: stacks-block-height,
        resolved-at: u0,
        resolution: "",
        tenant-refund-percentage: u0,
        landlord-penalty-percentage: u0
      }
    )
    
    (map-set dispute-participants dispute-id
      {
        tenant: (get tenant rental),
        landlord: (get landlord listing)
      }
    )
    
    (map-set property-disputes property-id
      (unwrap! (as-max-len?
        (append (get-property-disputes property-id) dispute-id)
        u20
      ) (ok dispute-id))
    )
    
    (var-set next-dispute-id (+ dispute-id u1))
    (ok dispute-id)
  )
)

(define-public (resolve-dispute
  (dispute-id uint)
  (resolution (string-ascii 256))
  (tenant-refund-percentage uint)
  (landlord-penalty-percentage uint)
)
  (let
    (
      (dispute (unwrap! (map-get? rental-disputes dispute-id) err-dispute-not-found))
      (participants (unwrap! (map-get? dispute-participants dispute-id) err-dispute-not-found))
      (rental (unwrap! (map-get? active-rentals (get property-id dispute)) err-listing-not-found))
      (listing (unwrap! (map-get? property-listings (get property-id dispute)) err-listing-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status dispute) u1) err-dispute-resolved)
    (asserts! (<= tenant-refund-percentage u100) err-invalid-refund-percentage)
    (asserts! (<= landlord-penalty-percentage u100) err-invalid-refund-percentage)
    
    (let
      (
        (total-funds (+ (get deposit-paid rental) (get rent-paid rental)))
        (tenant-refund (/ (* total-funds tenant-refund-percentage) u100))
        (landlord-penalty (/ (* total-funds landlord-penalty-percentage) u100))
        (landlord-payment (- total-funds (+ tenant-refund landlord-penalty)))
      )
      (if (> tenant-refund u0)
        (try! (as-contract (stx-transfer? tenant-refund tx-sender (get tenant participants))))
        true
      )
      
      (if (> landlord-payment u0)
        (try! (as-contract (stx-transfer? landlord-payment tx-sender (get landlord participants))))
        true
      )
      
      (map-set rental-disputes dispute-id
        (merge dispute {
          status: u2,
          resolved-at: stacks-block-height,
          resolution: resolution,
          tenant-refund-percentage: tenant-refund-percentage,
          landlord-penalty-percentage: landlord-penalty-percentage
        })
      )
      
      (map-set active-rentals (get property-id dispute)
        (merge rental { deposit-returned: true })
      )
      
      (ok true)
    )
  )
)

(define-public (close-disputed-rental (property-id uint))
  (let
    (
      (rental (unwrap! (map-get? active-rentals property-id) err-listing-not-found))
      (listing (unwrap! (map-get? property-listings property-id) err-listing-not-found))
    )
    (asserts!
      (or
        (is-eq tx-sender (get tenant rental))
        (is-eq tx-sender (get landlord listing))
      )
      err-not-dispute-party
    )
    
    (let
      (
        (dispute-list (get-property-disputes property-id))
        (has-resolved-dispute (fold check-resolved-dispute dispute-list false))
      )
      (asserts! has-resolved-dispute err-dispute-not-found)
      
      (try! (nft-burn? rental-property property-id (get tenant rental)))
      
      (map-delete active-rentals property-id)
      
      (map-set property-listings property-id
        (merge listing { available: true })
      )
      
      (ok true)
    )
  )
)

(define-private (check-resolved-dispute (dispute-id uint) (found bool))
  (if found
    true
    (match (map-get? rental-disputes dispute-id)
      dispute
      (is-eq (get status dispute) u2)
      false
    )
  )
)

;; Admin Functions
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
