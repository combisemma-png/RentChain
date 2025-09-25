;; RentChain Rental Agreement Contract
;; Manages property listings, lease agreements, and tenant applications

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-property-unavailable (err u104))
(define-constant err-application-exists (err u105))
(define-constant err-invalid-status (err u106))
(define-constant err-lease-active (err u107))
(define-constant err-insufficient-deposit (err u108))
(define-constant err-invalid-dates (err u109))
(define-constant err-property-occupied (err u110))

;; Data Variables
(define-data-var next-property-id uint u1)
(define-data-var next-application-id uint u1)
(define-data-var next-lease-id uint u1)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points

;; Property Status Constants
(define-constant status-available u0)
(define-constant status-occupied u1)
(define-constant status-maintenance u2)
(define-constant status-unlisted u3)

;; Application Status Constants
(define-constant app-status-pending u0)
(define-constant app-status-approved u1)
(define-constant app-status-rejected u2)
(define-constant app-status-withdrawn u3)

;; Lease Status Constants
(define-constant lease-status-active u0)
(define-constant lease-status-expired u1)
(define-constant lease-status-terminated u2)
(define-constant lease-status-renewed u3)

;; Data Maps

;; Property listings
(define-map properties
  { property-id: uint }
  {
    landlord: principal,
    property-address: (string-ascii 256),
    property-type: (string-ascii 64),
    bedrooms: uint,
    bathrooms: uint,
    square-feet: uint,
    monthly-rent: uint,
    security-deposit: uint,
    description: (string-ascii 512),
    amenities: (string-ascii 256),
    status: uint,
    created-at: uint,
    last-updated: uint,
    total-applications: uint,
    lease-terms-months: uint,
    utilities-included: bool,
    pet-friendly: bool,
    parking-available: bool
  }
)

;; Tenant applications
(define-map applications
  { application-id: uint }
  {
    property-id: uint,
    tenant: principal,
    full-name: (string-ascii 128),
    email: (string-ascii 64),
    phone: (string-ascii 32),
    employment-status: (string-ascii 64),
    monthly-income: uint,
    previous-address: (string-ascii 256),
    references: (string-ascii 512),
    application-fee: uint,
    status: uint,
    applied-at: uint,
    reviewed-at: (optional uint),
    notes: (optional (string-ascii 256))
  }
)

;; Active lease agreements
(define-map leases
  { lease-id: uint }
  {
    property-id: uint,
    landlord: principal,
    tenant: principal,
    monthly-rent: uint,
    security-deposit: uint,
    lease-start: uint,
    lease-end: uint,
    status: uint,
    created-at: uint,
    deposit-paid: bool,
    first-rent-paid: bool,
    special-terms: (optional (string-ascii 512)),
    renewal-count: uint,
    total-rent-paid: uint,
    maintenance-requests: uint
  }
)

;; Property-tenant relationship tracking
(define-map tenant-properties
  { tenant: principal, property-id: uint }
  {
    lease-id: uint,
    move-in-date: uint,
    move-out-date: (optional uint),
    rent-history-count: uint,
    maintenance-issues: uint,
    tenant-rating: uint,
    lease-violations: uint
  }
)

;; Landlord portfolio tracking
(define-map landlord-portfolio
  { landlord: principal }
  {
    total-properties: uint,
    occupied-properties: uint,
    total-rental-income: uint,
    active-leases: uint,
    tenant-applications: uint,
    average-rent: uint,
    portfolio-value: uint
  }
)

;; Security deposit tracking
(define-map security-deposits
  { lease-id: uint }
  {
    deposit-amount: uint,
    deposit-paid-at: uint,
    refund-amount: uint,
    refunded-at: (optional uint),
    deductions: uint,
    deduction-reasons: (optional (string-ascii 512)),
    is-refunded: bool
  }
)

;; Public Functions

;; Register a new rental property
(define-public (register-property
    (property-address (string-ascii 256))
    (property-type (string-ascii 64))
    (bedrooms uint)
    (bathrooms uint)
    (square-feet uint)
    (monthly-rent uint)
    (security-deposit uint)
    (description (string-ascii 512))
    (amenities (string-ascii 256))
    (lease-terms-months uint)
    (utilities-included bool)
    (pet-friendly bool)
    (parking-available bool))
  (let (
    (property-id (var-get next-property-id))
    (current-portfolio (default-to 
      { total-properties: u0, occupied-properties: u0, total-rental-income: u0, 
        active-leases: u0, tenant-applications: u0, average-rent: u0, portfolio-value: u0 }
      (map-get? landlord-portfolio { landlord: tx-sender })
    ))
  )
    (asserts! (> monthly-rent u0) err-invalid-amount)
    (asserts! (> security-deposit u0) err-invalid-amount)
    (asserts! (> lease-terms-months u0) err-invalid-amount)
    (asserts! (> square-feet u0) err-invalid-amount)
    
    ;; Create property listing
    (map-set properties
      { property-id: property-id }
      {
        landlord: tx-sender,
        property-address: property-address,
        property-type: property-type,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        square-feet: square-feet,
        monthly-rent: monthly-rent,
        security-deposit: security-deposit,
        description: description,
        amenities: amenities,
        status: status-available,
        created-at: stacks-block-height,
        last-updated: stacks-block-height,
        total-applications: u0,
        lease-terms-months: lease-terms-months,
        utilities-included: utilities-included,
        pet-friendly: pet-friendly,
        parking-available: parking-available
      }
    )
    
    ;; Update landlord portfolio
    (map-set landlord-portfolio
      { landlord: tx-sender }
      (merge current-portfolio {
        total-properties: (+ (get total-properties current-portfolio) u1),
        portfolio-value: (+ (get portfolio-value current-portfolio) monthly-rent)
      })
    )
    
    (var-set next-property-id (+ property-id u1))
    (ok property-id)
  )
)

;; Submit rental application
(define-public (submit-application
    (property-id uint)
    (full-name (string-ascii 128))
    (email (string-ascii 64))
    (phone (string-ascii 32))
    (employment-status (string-ascii 64))
    (monthly-income uint)
    (previous-address (string-ascii 256))
    (references (string-ascii 512))
    (application-fee uint))
  (let (
    (property (unwrap! (map-get? properties { property-id: property-id }) err-not-found))
    (application-id (var-get next-application-id))
  )
    (asserts! (is-eq (get status property) status-available) err-property-unavailable)
    (asserts! (> monthly-income u0) err-invalid-amount)
    (asserts! (>= application-fee u10000000) err-invalid-amount) ;; Minimum 10 STX application fee
    
    ;; Transfer application fee to landlord
    (try! (stx-transfer? application-fee tx-sender (get landlord property)))
    
    ;; Create application record
    (map-set applications
      { application-id: application-id }
      {
        property-id: property-id,
        tenant: tx-sender,
        full-name: full-name,
        email: email,
        phone: phone,
        employment-status: employment-status,
        monthly-income: monthly-income,
        previous-address: previous-address,
        references: references,
        application-fee: application-fee,
        status: app-status-pending,
        applied-at: stacks-block-height,
        reviewed-at: none,
        notes: none
      }
    )
    
    ;; Update property application count
    (map-set properties
      { property-id: property-id }
      (merge property {
        total-applications: (+ (get total-applications property) u1),
        last-updated: stacks-block-height
      })
    )
    
    (var-set next-application-id (+ application-id u1))
    (ok application-id)
  )
)

;; Approve or reject tenant application
(define-public (review-application
    (application-id uint)
    (approve bool)
    (notes (optional (string-ascii 256))))
  (let (
    (application (unwrap! (map-get? applications { application-id: application-id }) err-not-found))
    (property (unwrap! (map-get? properties { property-id: (get property-id application) }) err-not-found))
    (new-status (if approve app-status-approved app-status-rejected))
  )
    (asserts! (is-eq tx-sender (get landlord property)) err-unauthorized)
    (asserts! (is-eq (get status application) app-status-pending) err-invalid-status)
    
    ;; Update application status
    (map-set applications
      { application-id: application-id }
      (merge application {
        status: new-status,
        reviewed-at: (some stacks-block-height),
        notes: notes
      })
    )
    
    (ok approve)
  )
)

;; Create lease agreement (after approval)
(define-public (create-lease
    (application-id uint)
    (lease-start uint)
    (special-terms (optional (string-ascii 512))))
  (let (
    (application (unwrap! (map-get? applications { application-id: application-id }) err-not-found))
    (property (unwrap! (map-get? properties { property-id: (get property-id application) }) err-not-found))
    (lease-id (var-get next-lease-id))
    (lease-end (+ lease-start (* (get lease-terms-months property) u144 u30))) ;; Approximate blocks per month
  )
    (asserts! (is-eq tx-sender (get landlord property)) err-unauthorized)
    (asserts! (is-eq (get status application) app-status-approved) err-invalid-status)
    (asserts! (is-eq (get status property) status-available) err-property-unavailable)
    (asserts! (> lease-start stacks-block-height) err-invalid-dates)
    
    ;; Create lease agreement
    (map-set leases
      { lease-id: lease-id }
      {
        property-id: (get property-id application),
        landlord: (get landlord property),
        tenant: (get tenant application),
        monthly-rent: (get monthly-rent property),
        security-deposit: (get security-deposit property),
        lease-start: lease-start,
        lease-end: lease-end,
        status: lease-status-active,
        created-at: stacks-block-height,
        deposit-paid: false,
        first-rent-paid: false,
        special-terms: special-terms,
        renewal-count: u0,
        total-rent-paid: u0,
        maintenance-requests: u0
      }
    )
    
    ;; Initialize security deposit tracking
    (map-set security-deposits
      { lease-id: lease-id }
      {
        deposit-amount: (get security-deposit property),
        deposit-paid-at: u0,
        refund-amount: u0,
        refunded-at: none,
        deductions: u0,
        deduction-reasons: none,
        is-refunded: false
      }
    )
    
    ;; Update property status
    (map-set properties
      { property-id: (get property-id application) }
      (merge property { status: status-occupied })
    )
    
    ;; Track tenant-property relationship
    (map-set tenant-properties
      { tenant: (get tenant application), property-id: (get property-id application) }
      {
        lease-id: lease-id,
        move-in-date: lease-start,
        move-out-date: none,
        rent-history-count: u0,
        maintenance-issues: u0,
        tenant-rating: u5, ;; Start with neutral rating
        lease-violations: u0
      }
    )
    
    (var-set next-lease-id (+ lease-id u1))
    (ok lease-id)
  )
)

;; Pay security deposit
(define-public (pay-security-deposit (lease-id uint))
  (let (
    (lease (unwrap! (map-get? leases { lease-id: lease-id }) err-not-found))
    (deposit-info (unwrap! (map-get? security-deposits { lease-id: lease-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender (get tenant lease)) err-unauthorized)
    (asserts! (not (get deposit-paid lease)) err-invalid-status)
    
    ;; Transfer security deposit to contract
    (try! (stx-transfer? (get security-deposit lease) tx-sender (as-contract tx-sender)))
    
    ;; Update lease record
    (map-set leases
      { lease-id: lease-id }
      (merge lease { deposit-paid: true })
    )
    
    ;; Update deposit tracking
    (map-set security-deposits
      { lease-id: lease-id }
      (merge deposit-info {
        deposit-paid-at: stacks-block-height
      })
    )
    
    (ok true)
  )
)

;; Terminate lease agreement
(define-public (terminate-lease
    (lease-id uint)
    (termination-reason (string-ascii 256)))
  (let (
    (lease (unwrap! (map-get? leases { lease-id: lease-id }) err-not-found))
    (property (unwrap! (map-get? properties { property-id: (get property-id lease) }) err-not-found))
    (tenant-property (unwrap! (map-get? tenant-properties { tenant: (get tenant lease), property-id: (get property-id lease) }) err-not-found))
  )
    (asserts! (or (is-eq tx-sender (get landlord lease)) (is-eq tx-sender (get tenant lease))) err-unauthorized)
    (asserts! (is-eq (get status lease) lease-status-active) err-invalid-status)
    
    ;; Update lease status
    (map-set leases
      { lease-id: lease-id }
      (merge lease { status: lease-status-terminated })
    )
    
    ;; Update property availability
    (map-set properties
      { property-id: (get property-id lease) }
      (merge property { 
        status: status-available,
        last-updated: stacks-block-height
      })
    )
    
    ;; Update tenant-property relationship
    (map-set tenant-properties
      { tenant: (get tenant lease), property-id: (get property-id lease) }
      (merge tenant-property {
        move-out-date: (some stacks-block-height)
      })
    )
    
    (ok true)
  )
)

;; Read-only Functions

(define-read-only (get-property (property-id uint))
  (map-get? properties { property-id: property-id })
)

(define-read-only (get-application (application-id uint))
  (map-get? applications { application-id: application-id })
)

(define-read-only (get-lease (lease-id uint))
  (map-get? leases { lease-id: lease-id })
)

(define-read-only (get-landlord-portfolio (landlord principal))
  (map-get? landlord-portfolio { landlord: landlord })
)

(define-read-only (get-tenant-property (tenant principal) (property-id uint))
  (map-get? tenant-properties { tenant: tenant, property-id: property-id })
)

(define-read-only (get-security-deposit-info (lease-id uint))
  (map-get? security-deposits { lease-id: lease-id })
)

(define-read-only (get-next-property-id)
  (var-get next-property-id)
)

(define-read-only (get-platform-stats)
  {
    total-properties: (- (var-get next-property-id) u1),
    total-applications: (- (var-get next-application-id) u1),
    total-leases: (- (var-get next-lease-id) u1),
    platform-fee-rate: (var-get platform-fee-rate)
  }
)

