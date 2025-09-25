;; RentChain Payment Ledger Contract
;; Manages rent payments, late fees, and financial transaction history

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-unauthorized (err u202))
(define-constant err-invalid-amount (err u203))
(define-constant err-payment-exists (err u204))
(define-constant err-insufficient-balance (err u205))
(define-constant err-lease-inactive (err u206))
(define-constant err-payment-not-due (err u207))
(define-constant err-already-paid (err u208))
(define-constant err-late-payment (err u209))
(define-constant err-invalid-date (err u210))
(define-constant err-refund-processed (err u211))

;; Data Variables
(define-data-var next-payment-id uint u1)
(define-data-var next-invoice-id uint u1)
(define-data-var late-fee-rate uint u500) ;; 5% late fee in basis points
(define-data-var late-payment-grace-period uint u144) ;; ~1 day in blocks
(define-data-var platform-transaction-fee uint u100) ;; 1% in basis points

;; Payment Status Constants
(define-constant payment-status-pending u0)
(define-constant payment-status-paid u1)
(define-constant payment-status-late u2)
(define-constant payment-status-partial u3)
(define-constant payment-status-refunded u4)
(define-constant payment-status-disputed u5)

;; Invoice Status Constants
(define-constant invoice-status-generated u0)
(define-constant invoice-status-sent u1)
(define-constant invoice-status-paid u2)
(define-constant invoice-status-overdue u3)
(define-constant invoice-status-cancelled u4)

;; Data Maps

;; Monthly rent payments
(define-map rent-payments
  { payment-id: uint }
  {
    lease-id: uint,
    tenant: principal,
    landlord: principal,
    amount-due: uint,
    amount-paid: uint,
    late-fee: uint,
    due-date: uint,
    payment-date: (optional uint),
    status: uint,
    payment-method: (string-ascii 32),
    transaction-hash: (optional (string-ascii 64)),
    notes: (optional (string-ascii 256)),
    created-at: uint
  }
)

;; Payment history and ledger
(define-map payment-history
  { lease-id: uint, payment-period: uint }
  {
    rent-amount: uint,
    late-fees: uint,
    total-paid: uint,
    payment-date: uint,
    days-late: uint,
    payment-id: uint,
    is-partial: bool,
    remaining-balance: uint
  }
)

;; Security deposit refunds
(define-map deposit-refunds
  { lease-id: uint }
  {
    original-deposit: uint,
    refund-amount: uint,
    deductions: uint,
    deduction-details: (string-ascii 512),
    refund-date: (optional uint),
    refund-approved: bool,
    approved-by: (optional principal),
    tenant-acknowledged: bool,
    processing-fee: uint
  }
)

;; Monthly rent invoices
(define-map rent-invoices
  { invoice-id: uint }
  {
    lease-id: uint,
    tenant: principal,
    landlord: principal,
    rent-period-start: uint,
    rent-period-end: uint,
    base-rent: uint,
    additional-charges: uint,
    discounts: uint,
    total-due: uint,
    due-date: uint,
    status: uint,
    generated-at: uint,
    sent-at: (optional uint),
    paid-at: (optional uint),
    description: (string-ascii 256)
  }
)

;; Late payment tracking
(define-map late-payment-records
  { lease-id: uint }
  {
    total-late-payments: uint,
    total-late-fees: uint,
    longest-delay-days: uint,
    current-streak: uint,
    last-late-payment: (optional uint),
    warning-notices-sent: uint,
    eviction-notices-sent: uint
  }
)

;; Financial summaries per lease
(define-map lease-financials
  { lease-id: uint }
  {
    total-rent-collected: uint,
    total-late-fees: uint,
    total-refunds: uint,
    outstanding-balance: uint,
    last-payment-date: (optional uint),
    payment-streak: uint,
    average-payment-delay: uint,
    total-transactions: uint
  }
)

;; Landlord financial dashboard
(define-map landlord-finances
  { landlord: principal }
  {
    total-rental-income: uint,
    total-late-fees-collected: uint,
    outstanding-rent: uint,
    total-refunds-processed: uint,
    active-leases-count: uint,
    delinquent-tenants: uint,
    average-collection-time: uint,
    monthly-cash-flow: uint
  }
)

;; Tenant payment profiles
(define-map tenant-payment-profiles
  { tenant: principal }
  {
    total-rent-paid: uint,
    total-late-fees: uint,
    payment-reliability-score: uint,
    late-payment-count: uint,
    on-time-payment-count: uint,
    current-outstanding: uint,
    payment-history-months: uint,
    last-payment-date: (optional uint)
  }
)

;; Automatic payment scheduling
(define-map auto-payment-schedule
  { lease-id: uint }
  {
    is-enabled: bool,
    next-payment-date: uint,
    payment-amount: uint,
    payment-day-of-month: uint,
    consecutive-successful: uint,
    last-auto-payment: (optional uint),
    auto-payment-failures: uint
  }
)

;; Public Functions

;; Generate monthly rent invoice
(define-public (generate-rent-invoice
    (lease-id uint)
    (rent-period-start uint)
    (rent-period-end uint)
    (base-rent uint)
    (additional-charges uint)
    (discounts uint)
    (description (string-ascii 256)))
  (let (
    (invoice-id (var-get next-invoice-id))
    (total-due (+ (- base-rent discounts) additional-charges))
    (due-date (+ rent-period-end u144)) ;; Due 1 day after period ends
  )
    (asserts! (> base-rent u0) err-invalid-amount)
    (asserts! (> rent-period-end rent-period-start) err-invalid-date)
    (asserts! (> rent-period-end stacks-block-height) err-invalid-date)
    
    ;; Create invoice
    (map-set rent-invoices
      { invoice-id: invoice-id }
      {
        lease-id: lease-id,
        tenant: tx-sender,
        landlord: tx-sender, ;; Will be updated when linked to lease
        rent-period-start: rent-period-start,
        rent-period-end: rent-period-end,
        base-rent: base-rent,
        additional-charges: additional-charges,
        discounts: discounts,
        total-due: total-due,
        due-date: due-date,
        status: invoice-status-generated,
        generated-at: stacks-block-height,
        sent-at: none,
        paid-at: none,
        description: description
      }
    )
    
    (var-set next-invoice-id (+ invoice-id u1))
    (ok invoice-id)
  )
)

;; Process rent payment
(define-public (pay-rent
    (lease-id uint)
    (payment-amount uint)
    (payment-method (string-ascii 32))
    (notes (optional (string-ascii 256))))
  (let (
    (payment-id (var-get next-payment-id))
    (current-block stacks-block-height)
    (current-financials (default-to 
      { total-rent-collected: u0, total-late-fees: u0, total-refunds: u0, 
        outstanding-balance: u0, last-payment-date: none, payment-streak: u0, 
        average-payment-delay: u0, total-transactions: u0 }
      (map-get? lease-financials { lease-id: lease-id })
    ))
    (tenant-profile (default-to 
      { total-rent-paid: u0, total-late-fees: u0, payment-reliability-score: u100, 
        late-payment-count: u0, on-time-payment-count: u0, current-outstanding: u0, 
        payment-history-months: u0, last-payment-date: none }
      (map-get? tenant-payment-profiles { tenant: tx-sender })
    ))
  )
    (asserts! (> payment-amount u0) err-invalid-amount)
    
    ;; Transfer rent payment to contract (will be forwarded to landlord)
    (try! (stx-transfer? payment-amount tx-sender (as-contract tx-sender)))
    
    ;; Create payment record
    (map-set rent-payments
      { payment-id: payment-id }
      {
        lease-id: lease-id,
        tenant: tx-sender,
        landlord: tx-sender, ;; Will be updated when linked to lease
        amount-due: payment-amount,
        amount-paid: payment-amount,
        late-fee: u0,
        due-date: current-block,
        payment-date: (some current-block),
        status: payment-status-paid,
        payment-method: payment-method,
        transaction-hash: none,
        notes: notes,
        created-at: current-block
      }
    )
    
    ;; Update lease financials
    (map-set lease-financials
      { lease-id: lease-id }
      (merge current-financials {
        total-rent-collected: (+ (get total-rent-collected current-financials) payment-amount),
        last-payment-date: (some current-block),
        payment-streak: (+ (get payment-streak current-financials) u1),
        total-transactions: (+ (get total-transactions current-financials) u1)
      })
    )
    
    ;; Update tenant payment profile
    (map-set tenant-payment-profiles
      { tenant: tx-sender }
      (merge tenant-profile {
        total-rent-paid: (+ (get total-rent-paid tenant-profile) payment-amount),
        on-time-payment-count: (+ (get on-time-payment-count tenant-profile) u1),
        last-payment-date: (some current-block),
        payment-reliability-score: (if (<= (+ (get payment-reliability-score tenant-profile) u5) u100) (+ (get payment-reliability-score tenant-profile) u5) u100)
      })
    )
    
    (var-set next-payment-id (+ payment-id u1))
    (ok payment-id)
  )
)

;; Process late payment with fees
(define-public (pay-late-rent
    (lease-id uint)
    (base-rent uint)
    (days-late uint)
    (payment-method (string-ascii 32)))
  (let (
    (late-fee (/ (* base-rent (var-get late-fee-rate)) u10000))
    (total-payment (+ base-rent late-fee))
    (payment-id (var-get next-payment-id))
    (current-late-records (default-to 
      { total-late-payments: u0, total-late-fees: u0, longest-delay-days: u0, 
        current-streak: u0, last-late-payment: none, warning-notices-sent: u0, 
        eviction-notices-sent: u0 }
      (map-get? late-payment-records { lease-id: lease-id })
    ))
  )
    (asserts! (> base-rent u0) err-invalid-amount)
    (asserts! (> days-late u0) err-invalid-amount)
    
    ;; Transfer total payment (rent + late fee)
    (try! (stx-transfer? total-payment tx-sender (as-contract tx-sender)))
    
    ;; Create late payment record
    (map-set rent-payments
      { payment-id: payment-id }
      {
        lease-id: lease-id,
        tenant: tx-sender,
        landlord: tx-sender,
        amount-due: base-rent,
        amount-paid: total-payment,
        late-fee: late-fee,
        due-date: (- stacks-block-height (* days-late u144)),
        payment-date: (some stacks-block-height),
        status: payment-status-late,
        payment-method: payment-method,
        transaction-hash: none,
        notes: (some "Late payment with penalty"),
        created-at: stacks-block-height
      }
    )
    
    ;; Update late payment tracking
    (map-set late-payment-records
      { lease-id: lease-id }
      (merge current-late-records {
        total-late-payments: (+ (get total-late-payments current-late-records) u1),
        total-late-fees: (+ (get total-late-fees current-late-records) late-fee),
        longest-delay-days: (if (>= (get longest-delay-days current-late-records) days-late) (get longest-delay-days current-late-records) days-late),
        current-streak: (+ (get current-streak current-late-records) u1),
        last-late-payment: (some stacks-block-height)
      })
    )
    
    ;; Update tenant payment profile (negative impact)
    (match (map-get? tenant-payment-profiles { tenant: tx-sender })
      tenant-profile
        (map-set tenant-payment-profiles
          { tenant: tx-sender }
          (merge tenant-profile {
            total-rent-paid: (+ (get total-rent-paid tenant-profile) base-rent),
            total-late-fees: (+ (get total-late-fees tenant-profile) late-fee),
            late-payment-count: (+ (get late-payment-count tenant-profile) u1),
            payment-reliability-score: (if (>= (get payment-reliability-score tenant-profile) u10) (- (get payment-reliability-score tenant-profile) u10) u0)
          })
        )
      ;; Create new profile if doesn't exist
      (map-set tenant-payment-profiles
        { tenant: tx-sender }
        {
          total-rent-paid: base-rent,
          total-late-fees: late-fee,
          payment-reliability-score: u90,
          late-payment-count: u1,
          on-time-payment-count: u0,
          current-outstanding: u0,
          payment-history-months: u1,
          last-payment-date: (some stacks-block-height)
        }
      )
    )
    
    (var-set next-payment-id (+ payment-id u1))
    (ok payment-id)
  )
)

;; Process security deposit refund
(define-public (process-deposit-refund
    (lease-id uint)
    (refund-amount uint)
    (deductions uint)
    (deduction-details (string-ascii 512)))
  (let (
    (total-deposit (+ refund-amount deductions))
    (processing-fee (/ (* refund-amount (var-get platform-transaction-fee)) u10000))
    (net-refund (- refund-amount processing-fee))
  )
    (asserts! (> total-deposit u0) err-invalid-amount)
    (asserts! (>= refund-amount processing-fee) err-invalid-amount)
    
    ;; Create refund record
    (map-set deposit-refunds
      { lease-id: lease-id }
      {
        original-deposit: total-deposit,
        refund-amount: refund-amount,
        deductions: deductions,
        deduction-details: deduction-details,
        refund-date: (some stacks-block-height),
        refund-approved: true,
        approved-by: (some tx-sender),
        tenant-acknowledged: false,
        processing-fee: processing-fee
      }
    )
    
    ;; Transfer net refund to tenant (will be implemented with lease data)
    ;; (try! (as-contract (stx-transfer? net-refund tx-sender tenant-address)))
    
    (ok net-refund)
  )
)

;; Setup automatic payment schedule
(define-public (setup-auto-payment
    (lease-id uint)
    (payment-day-of-month uint)
    (monthly-amount uint))
  (begin
    (asserts! (<= payment-day-of-month u31) err-invalid-amount)
    (asserts! (> monthly-amount u0) err-invalid-amount)
    
    (map-set auto-payment-schedule
      { lease-id: lease-id }
      {
        is-enabled: true,
        next-payment-date: (+ stacks-block-height (* payment-day-of-month u144)),
        payment-amount: monthly-amount,
        payment-day-of-month: payment-day-of-month,
        consecutive-successful: u0,
        last-auto-payment: none,
        auto-payment-failures: u0
      }
    )
    
    (ok true)
  )
)

;; Generate financial report
(define-public (generate-financial-report (lease-id uint))
  (let (
    (financials (default-to 
      { total-rent-collected: u0, total-late-fees: u0, total-refunds: u0, 
        outstanding-balance: u0, last-payment-date: none, payment-streak: u0, 
        average-payment-delay: u0, total-transactions: u0 }
      (map-get? lease-financials { lease-id: lease-id })
    ))
  )
    (ok financials)
  )
)

;; Read-only Functions

(define-read-only (get-payment (payment-id uint))
  (map-get? rent-payments { payment-id: payment-id })
)

(define-read-only (get-invoice (invoice-id uint))
  (map-get? rent-invoices { invoice-id: invoice-id })
)

(define-read-only (get-payment-history (lease-id uint) (payment-period uint))
  (map-get? payment-history { lease-id: lease-id, payment-period: payment-period })
)

(define-read-only (get-late-payment-records (lease-id uint))
  (map-get? late-payment-records { lease-id: lease-id })
)

(define-read-only (get-lease-financials (lease-id uint))
  (map-get? lease-financials { lease-id: lease-id })
)

(define-read-only (get-tenant-payment-profile (tenant principal))
  (map-get? tenant-payment-profiles { tenant: tenant })
)

(define-read-only (get-landlord-finances (landlord principal))
  (map-get? landlord-finances { landlord: landlord })
)

(define-read-only (get-deposit-refund-info (lease-id uint))
  (map-get? deposit-refunds { lease-id: lease-id })
)

(define-read-only (get-auto-payment-schedule (lease-id uint))
  (map-get? auto-payment-schedule { lease-id: lease-id })
)

(define-read-only (get-payment-stats)
  {
    total-payments: (- (var-get next-payment-id) u1),
    total-invoices: (- (var-get next-invoice-id) u1),
    late-fee-rate: (var-get late-fee-rate),
    platform-fee: (var-get platform-transaction-fee)
  }
)

