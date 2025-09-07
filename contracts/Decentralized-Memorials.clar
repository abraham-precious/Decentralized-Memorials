;; Decentralized Memorials - Permanent NFT gravestones
;; Advanced Clarity smart contract for creating and managing digital memorials
;; Features: Access controls, moderation, tributes, categorization, and versioning

;; Contract owner and admin roles
(define-constant contract-owner tx-sender)
(define-data-var admin-list (list 10 principal) (list contract-owner))

;; Error constants
(define-constant err-owner-only (err u100))
(define-constant err-admin-only (err u101))
(define-constant err-memorial-not-found (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-not-authorized (err u104))
(define-constant err-pending-approval (err u105))
(define-constant err-invalid-input (err u106))
(define-constant err-insufficient-payment (err u107))
(define-constant err-memorial-locked (err u108))

;; Memorial status constants
(define-constant status-pending u0)
(define-constant status-approved u1)
(define-constant status-rejected u2)
(define-constant status-archived u3)

;; Configuration variables
(define-data-var memorial-creation-fee uint u1000000) ;; 1 STX in microSTX
(define-data-var require-approval bool true)
(define-data-var max-tributes-per-memorial uint u100)

(define-data-var last-memorial-id uint u0)
(define-data-var last-tribute-id uint u0)

;; Enhanced memorial structure with additional metadata
(define-map memorials
  { memorial-id: uint }
  {
    creator: principal,
    name: (string-ascii 100),
    birth-date: (string-ascii 20),
    death-date: (string-ascii 20),
    epitaph: (string-utf8 500),
    image-uri: (string-ascii 255),
    created-at: uint,
    updated-at: uint,
    status: uint,
    category: (string-ascii 50),
    tags: (list 10 (string-ascii 30)),
    tribute-count: uint,
    total-donations: uint,
    is-public: bool,
    location: (optional (string-ascii 100)),
    version: uint
  }
)

;; Memorial version history
(define-map memorial-versions
  { memorial-id: uint, version: uint }
  {
    epitaph: (string-utf8 500),
    image-uri: (string-ascii 255),
    updated-by: principal,
    updated-at: uint,
    change-reason: (string-utf8 200)
  }
)

;; Tributes and messages
(define-map tributes
  { tribute-id: uint }
  {
    memorial-id: uint,
    author: principal,
    message: (string-utf8 1000),
    donation-amount: uint,
    created-at: uint,
    is-anonymous: bool
  }
)

;; Memorial categories for organization
(define-map categories
  { category-name: (string-ascii 50) }
  {
    description: (string-utf8 200),
    memorial-count: uint,
    created-by: principal
  }
)

;; Enhanced ownership with permissions
(define-map memorial-owners
  { memorial-id: uint }
  { owner: principal }
)

;; Memorial permissions for collaborative management
(define-map memorial-permissions
  { memorial-id: uint, user: principal }
  {
    can-edit: bool,
    can-moderate: bool,
    can-view-private: bool,
    granted-by: principal,
    granted-at: uint
  }
)

;; Moderation queue for pending memorials
(define-map moderation-queue
  { memorial-id: uint }
  {
    submitted-at: uint,
    reviewed-by: (optional principal),
    reviewed-at: (optional uint),
    rejection-reason: (optional (string-utf8 200))
  }
)

;; Helper functions for access control
(define-private (is-admin (user principal))
  (is-some (index-of (var-get admin-list) user))
)

(define-private (is-memorial-editor (memorial-id uint) (user principal))
  (or 
    (is-eq user (unwrap! (get owner (map-get? memorial-owners { memorial-id: memorial-id })) false))
    (default-to false (get can-edit (map-get? memorial-permissions { memorial-id: memorial-id, user: user })))
  )
)

;; Admin functions
(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (< (len (var-get admin-list)) u10) err-invalid-input)
    (var-set admin-list (unwrap-panic (as-max-len? (append (var-get admin-list) new-admin) u10)))
    (ok true)
  )
)

(define-public (remove-admin (admin principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set admin-list (filter is-not-target-admin (var-get admin-list)))
    (ok true)
  )
)

(define-private (is-not-target-admin (admin principal))
  (not (is-eq admin admin))
)

;; Enhanced memorial creation with fees and approval
(define-public (create-memorial 
    (name (string-ascii 100))
    (birth-date (string-ascii 20))
    (death-date (string-ascii 20))
    (epitaph (string-utf8 500))
    (image-uri (string-ascii 255))
    (category (string-ascii 50))
    (tags (list 10 (string-ascii 30)))
    (is-public bool)
    (location (optional (string-ascii 100))))
  (let (
    (memorial-id (+ (var-get last-memorial-id) u1))
    (creation-fee (var-get memorial-creation-fee))
    (initial-status (if (var-get require-approval) status-pending status-approved))
  )
    ;; Check fee payment
    (if (> creation-fee u0)
      (try! (stx-transfer? creation-fee tx-sender contract-owner))
      true
    )
    ;; Validate inputs
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> (len epitaph) u0) err-invalid-input)

    ;; Create memorial
    (map-set memorials
      { memorial-id: memorial-id }
      {
        creator: tx-sender,
        name: name,
        birth-date: birth-date,
        death-date: death-date,
        epitaph: epitaph,
        image-uri: image-uri,
        created-at: block-height,
        updated-at: block-height,
        status: initial-status,
        category: category,
        tags: tags,
        tribute-count: u0,
        total-donations: u0,
        is-public: is-public,
        location: location,
        version: u1
      }
    )

    ;; Set ownership
    (map-set memorial-owners
      { memorial-id: memorial-id }
      { owner: tx-sender }
    )

    ;; Add to moderation queue if approval required
    (if (var-get require-approval)
      (map-set moderation-queue
        { memorial-id: memorial-id }
        {
          submitted-at: block-height,
          reviewed-by: none,
          reviewed-at: none,
          rejection-reason: none
        }
      )
      true
    )

    ;; Update category count
    (map-set categories
      { category-name: category }
      {
        description: (default-to u"" (get description (map-get? categories { category-name: category }))),
        memorial-count: (+ u1 (default-to u0 (get memorial-count (map-get? categories { category-name: category })))),
        created-by: (default-to tx-sender (get created-by (map-get? categories { category-name: category })))
      }
    )

    (var-set last-memorial-id memorial-id)
    (ok memorial-id)
  )
)

;; Moderation functions
(define-public (approve-memorial (memorial-id uint))
  (let ((memorial-data (unwrap! (map-get? memorials { memorial-id: memorial-id }) err-memorial-not-found)))
    (asserts! (is-admin tx-sender) err-admin-only)
    (asserts! (is-eq (get status memorial-data) status-pending) err-invalid-input)

    (map-set memorials
      { memorial-id: memorial-id }
      (merge memorial-data { status: status-approved, updated-at: block-height })
    )

    (map-set moderation-queue
      { memorial-id: memorial-id }
      (merge 
        (unwrap-panic (map-get? moderation-queue { memorial-id: memorial-id }))
        { reviewed-by: (some tx-sender), reviewed-at: (some block-height) }
      )
    )
    (ok true)
  )
)

(define-public (reject-memorial (memorial-id uint) (reason (string-utf8 200)))
  (let ((memorial-data (unwrap! (map-get? memorials { memorial-id: memorial-id }) err-memorial-not-found)))
    (asserts! (is-admin tx-sender) err-admin-only)
    (asserts! (is-eq (get status memorial-data) status-pending) err-invalid-input)

    (map-set memorials
      { memorial-id: memorial-id }
      (merge memorial-data { status: status-rejected, updated-at: block-height })
    )

    (map-set moderation-queue
      { memorial-id: memorial-id }
      (merge 
        (unwrap-panic (map-get? moderation-queue { memorial-id: memorial-id }))
        { reviewed-by: (some tx-sender), reviewed-at: (some block-height), rejection-reason: (some reason) }
      )
    )
    (ok true)
  )
)

;; Tribute and donation functions
(define-public (add-tribute 
    (memorial-id uint)
    (message (string-utf8 1000))
    (donation-amount uint)
    (is-anonymous bool))
  (let (
    (tribute-id (+ (var-get last-tribute-id) u1))
    (memorial-data (unwrap! (map-get? memorials { memorial-id: memorial-id }) err-memorial-not-found))
  )
    (asserts! (is-eq (get status memorial-data) status-approved) err-pending-approval)
    (asserts! (< (get tribute-count memorial-data) (var-get max-tributes-per-memorial)) err-invalid-input)

    (if (> donation-amount u0)
      (try! (stx-transfer? donation-amount tx-sender (get creator memorial-data)))
      true
    )

    (map-set tributes
      { tribute-id: tribute-id }
      {
        memorial-id: memorial-id,
        author: tx-sender,
        message: message,
        donation-amount: donation-amount,
        created-at: block-height,
        is-anonymous: is-anonymous
      }
    )

    (map-set memorials
      { memorial-id: memorial-id }
      (merge memorial-data {
        tribute-count: (+ (get tribute-count memorial-data) u1),
        total-donations: (+ (get total-donations memorial-data) donation-amount),
        updated-at: block-height
      })
    )

    (var-set last-tribute-id tribute-id)
    (ok tribute-id)
  )
)

;; Memorial editing with version history
(define-public (update-memorial 
    (memorial-id uint)
    (new-epitaph (string-utf8 500))
    (new-image-uri (string-ascii 255))
    (change-reason (string-utf8 200)))
  (let (
    (memorial-data (unwrap! (map-get? memorials { memorial-id: memorial-id }) err-memorial-not-found))
    (current-version (get version memorial-data))
    (new-version (+ current-version u1))
  )
    (asserts! (is-memorial-editor memorial-id tx-sender) err-not-authorized)
    (asserts! (is-eq (get status memorial-data) status-approved) err-pending-approval)

    (map-set memorial-versions
      { memorial-id: memorial-id, version: current-version }
      {
        epitaph: (get epitaph memorial-data),
        image-uri: (get image-uri memorial-data),
        updated-by: tx-sender,
        updated-at: block-height,
        change-reason: change-reason
      }
    )

    (map-set memorials
      { memorial-id: memorial-id }
      (merge memorial-data {
        epitaph: new-epitaph,
        image-uri: new-image-uri,
        updated-at: block-height,
        version: new-version
      })
    )
    (ok new-version)
  )
)

;; Permission management
(define-public (grant-permission 
    (memorial-id uint)
    (user principal)
    (can-edit bool)
    (can-moderate bool)
    (can-view-private bool))
  (let ((memorial-owner (unwrap! (get owner (map-get? memorial-owners { memorial-id: memorial-id })) err-memorial-not-found)))
    (asserts! (or (is-eq tx-sender memorial-owner) (is-admin tx-sender)) err-not-authorized)

    (map-set memorial-permissions
      { memorial-id: memorial-id, user: user }
      {
        can-edit: can-edit,
        can-moderate: can-moderate,
        can-view-private: can-view-private,
        granted-by: tx-sender,
        granted-at: block-height
      }
    )
    (ok true)
  )
)

(define-public (revoke-permission (memorial-id uint) (user principal))
  (let ((memorial-owner (unwrap! (get owner (map-get? memorial-owners { memorial-id: memorial-id })) err-memorial-not-found)))
    (asserts! (or (is-eq tx-sender memorial-owner) (is-admin tx-sender)) err-not-authorized)
    (map-delete memorial-permissions { memorial-id: memorial-id, user: user })
    (ok true)
  )
)

;; Category management
(define-public (create-category 
    (category-name (string-ascii 50))
    (description (string-utf8 200)))
  (begin
    (asserts! (is-none (map-get? categories { category-name: category-name })) err-already-exists)
    (map-set categories
      { category-name: category-name }
      {
        description: description,
        memorial-count: u0,
        created-by: tx-sender
      }
    )
    (ok true)
  )
)

;; Enhanced read functions
(define-read-only (get-memorial (memorial-id uint))
  (let ((memorial-data (map-get? memorials { memorial-id: memorial-id })))
    (match memorial-data
      memorial (if (or (get is-public memorial) (is-memorial-editor memorial-id tx-sender))
                  (some memorial)
                  none)
      none
    )
  )
)

(define-read-only (get-memorial-owner (memorial-id uint))
  (map-get? memorial-owners { memorial-id: memorial-id })
)

(define-read-only (get-total-memorials)
  (var-get last-memorial-id)
)

(define-read-only (get-tribute (tribute-id uint))
  (map-get? tributes { tribute-id: tribute-id })
)

(define-read-only (get-memorial-version (memorial-id uint) (version uint))
  (map-get? memorial-versions { memorial-id: memorial-id, version: version })
)

(define-read-only (get-category (category-name (string-ascii 50)))
  (map-get? categories { category-name: category-name })
)

(define-read-only (get-memorial-permissions (memorial-id uint) (user principal))
  (map-get? memorial-permissions { memorial-id: memorial-id, user: user })
)

(define-read-only (get-moderation-status (memorial-id uint))
  (map-get? moderation-queue { memorial-id: memorial-id })
)

(define-read-only (get-contract-stats)
  {
    total-memorials: (var-get last-memorial-id),
    total-tributes: (var-get last-tribute-id),
    creation-fee: (var-get memorial-creation-fee),
    approval-required: (var-get require-approval)
  }
)

;; Enhanced transfer with permission checks
(define-public (transfer-memorial (memorial-id uint) (new-owner principal))
  (let ((current-owner (unwrap! (get owner (map-get? memorial-owners { memorial-id: memorial-id })) err-memorial-not-found)))
    (asserts! (is-eq tx-sender current-owner) err-owner-only)

    (map-set memorial-owners
      { memorial-id: memorial-id }
      { owner: new-owner }
    )
    (ok true)
  )
)

;; Configuration functions (admin only)
(define-public (set-memorial-fee (new-fee uint))
  (begin
    (asserts! (is-admin tx-sender) err-admin-only)
    (var-set memorial-creation-fee new-fee)
    (ok true)
  )
)

(define-public (set-approval-requirement (required bool))
  (begin
    (asserts! (is-admin tx-sender) err-admin-only)
    (var-set require-approval required)
    (ok true)
  )
)

;; Emergency functions
(define-public (archive-memorial (memorial-id uint) (reason (string-utf8 200)))
  (let ((memorial-data (unwrap! (map-get? memorials { memorial-id: memorial-id }) err-memorial-not-found)))
    (asserts! (is-admin tx-sender) err-admin-only)
    (map-set memorials
      { memorial-id: memorial-id }
      (merge memorial-data { status: status-archived, updated-at: block-height })
    )
    (ok true)
  )
)

;; Financial functions
(define-public (withdraw-fees)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let ((contract-balance (stx-get-balance (as-contract tx-sender))))
      (if (> contract-balance u0)
        (as-contract (stx-transfer? contract-balance tx-sender contract-owner))
        (ok true)
      )
    )
  )
)

;; Utility functions
(define-read-only (is-memorial-owner (memorial-id uint) (user principal))
  (match (map-get? memorial-owners { memorial-id: memorial-id })
    owner-data (is-eq (get owner owner-data) user)
    false
  )
)

(define-read-only (get-memorials-by-creator (creator principal))
  (ok creator)
)

(define-read-only (get-memorials-by-category (category (string-ascii 50)))
  (ok category)
)

(define-read-only (search-memorials-by-tag (tag (string-ascii 30)))
  (ok tag)
)