;; Parking Spaces Contract
;; Core contract for managing parking space registration and availability

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SPACE-NOT-FOUND (err u101))
(define-constant ERR-SPACE-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-PRICE (err u103))
(define-constant ERR-INVALID-LOCATION (err u104))
(define-constant ERR-SPACE-INACTIVE (err u105))
(define-constant ERR-INVALID-INPUT (err u106))

;; Data Variables
(define-data-var next-space-id uint u1)
(define-data-var total-spaces uint u0)

;; Data Maps
(define-map parking-spaces
  { space-id: uint }
  {
    owner: principal,
    location: { lat: int, lng: int },
    address: (string-ascii 200),
    pricing: { hourly: uint, daily: uint, monthly: uint },
    space-type: (string-ascii 50),
    features: (list 10 (string-ascii 50)),
    status: (string-ascii 20),
    created-at: uint,
    updated-at: uint
  }
)

(define-map space-availability
  { space-id: uint }
  {
    is-available: bool,
    available-from: uint,
    available-until: uint,
    maintenance-mode: bool
  }
)

(define-map owner-spaces
  { owner: principal }
  { space-ids: (list 100 uint), count: uint }
)

(define-map space-stats
  { space-id: uint }
  {
    total-bookings: uint,
    total-revenue: uint,
    rating: uint,
    review-count: uint
  }
)

;; Read-only functions

(define-read-only (get-space (space-id uint))
  (map-get? parking-spaces { space-id: space-id })
)

(define-read-only (get-space-availability (space-id uint))
  (map-get? space-availability { space-id: space-id })
)

(define-read-only (get-owner-spaces (owner principal))
  (default-to
    { space-ids: (list), count: u0 }
    (map-get? owner-spaces { owner: owner })
  )
)

(define-read-only (get-space-stats (space-id uint))
  (default-to
    { total-bookings: u0, total-revenue: u0, rating: u0, review-count: u0 }
    (map-get? space-stats { space-id: space-id })
  )
)

(define-read-only (get-total-spaces)
  (var-get total-spaces)
)

(define-read-only (get-next-space-id)
  (var-get next-space-id)
)

(define-read-only (is-space-available (space-id uint) (start-time uint) (end-time uint))
  (let (
    (space-data (unwrap! (get-space space-id) false))
    (availability (unwrap! (get-space-availability space-id) false))
  )
    (and
      (get is-available availability)
      (not (get maintenance-mode availability))
      (>= start-time (get available-from availability))
      (<= end-time (get available-until availability))
      (is-eq (get status space-data) "active")
    )
  )
)

(define-read-only (calculate-cost (space-id uint) (duration-hours uint))
  (let (
    (space-data (unwrap! (get-space space-id) (err ERR-SPACE-NOT-FOUND)))
    (pricing (get pricing space-data))
  )
    (if (<= duration-hours u24)
      (ok (* (get hourly pricing) duration-hours))
      (if (<= duration-hours u168) ;; 7 days
        (ok (* (get daily pricing) (/ (+ duration-hours u23) u24)))
        (ok (* (get monthly pricing) (/ (+ duration-hours u719) u720))) ;; 30 days
      )
    )
  )
)

;; Public functions

(define-public (register-space
  (location { lat: int, lng: int })
  (address (string-ascii 200))
  (pricing { hourly: uint, daily: uint, monthly: uint })
  (space-type (string-ascii 50))
  (features (list 10 (string-ascii 50)))
)
  (let (
    (space-id (var-get next-space-id))
    (current-owner-data (get-owner-spaces tx-sender))
  )
    ;; Validate inputs
    (asserts! (> (get hourly pricing) u0) ERR-INVALID-PRICE)
    (asserts! (> (get daily pricing) u0) ERR-INVALID-PRICE)
    (asserts! (> (get monthly pricing) u0) ERR-INVALID-PRICE)
    (asserts! (and (>= (get lat location) -90000000) (<= (get lat location) 90000000)) ERR-INVALID-LOCATION)
    (asserts! (and (>= (get lng location) -180000000) (<= (get lng location) 180000000)) ERR-INVALID-LOCATION)
    (asserts! (> (len address) u0) ERR-INVALID-INPUT)
    (asserts! (> (len space-type) u0) ERR-INVALID-INPUT)

    ;; Create parking space
    (map-set parking-spaces
      { space-id: space-id }
      {
        owner: tx-sender,
        location: location,
        address: address,
        pricing: pricing,
        space-type: space-type,
        features: features,
        status: "active",
        created-at: block-height,
        updated-at: block-height
      }
    )

    ;; Set initial availability
    (map-set space-availability
      { space-id: space-id }
      {
        is-available: true,
        available-from: block-height,
        available-until: (+ block-height u52560), ;; ~1 year
        maintenance-mode: false
      }
    )

    ;; Initialize stats
    (map-set space-stats
      { space-id: space-id }
      {
        total-bookings: u0,
        total-revenue: u0,
        rating: u0,
        review-count: u0
      }
    )

    ;; Update owner spaces
    (map-set owner-spaces
      { owner: tx-sender }
      {
        space-ids: (unwrap! (as-max-len? (append (get space-ids current-owner-data) space-id) u100) ERR-INVALID-INPUT),
        count: (+ (get count current-owner-data) u1)
      }
    )

    ;; Update counters
    (var-set next-space-id (+ space-id u1))
    (var-set total-spaces (+ (var-get total-spaces) u1))

    (ok space-id)
  )
)

(define-public (update-space-pricing
  (space-id uint)
  (new-pricing { hourly: uint, daily: uint, monthly: uint })
)
  (let (
    (space-data (unwrap! (get-space space-id) ERR-SPACE-NOT-FOUND))
  )
    ;; Check authorization
    (asserts! (is-eq tx-sender (get owner space-data)) ERR-NOT-AUTHORIZED)

    ;; Validate pricing
    (asserts! (> (get hourly new-pricing) u0) ERR-INVALID-PRICE)
    (asserts! (> (get daily new-pricing) u0) ERR-INVALID-PRICE)
    (asserts! (> (get monthly new-pricing) u0) ERR-INVALID-PRICE)

    ;; Update space
    (map-set parking-spaces
      { space-id: space-id }
      (merge space-data {
        pricing: new-pricing,
        updated-at: block-height
      })
    )

    (ok true)
  )
)

(define-public (update-space-availability
  (space-id uint)
  (is-available bool)
  (available-from uint)
  (available-until uint)
)
  (let (
    (space-data (unwrap! (get-space space-id) ERR-SPACE-NOT-FOUND))
  )
    ;; Check authorization
    (asserts! (is-eq tx-sender (get owner space-data)) ERR-NOT-AUTHORIZED)

    ;; Validate time range
    (asserts! (< available-from available-until) ERR-INVALID-INPUT)
    (asserts! (>= available-from block-height) ERR-INVALID-INPUT)

    ;; Update availability
    (map-set space-availability
      { space-id: space-id }
      {
        is-available: is-available,
        available-from: available-from,
        available-until: available-until,
        maintenance-mode: false
      }
    )

    (ok true)
  )
)

(define-public (set-maintenance-mode (space-id uint) (maintenance bool))
  (let (
    (space-data (unwrap! (get-space space-id) ERR-SPACE-NOT-FOUND))
    (availability (unwrap! (get-space-availability space-id) ERR-SPACE-NOT-FOUND))
  )
    ;; Check authorization
    (asserts! (is-eq tx-sender (get owner space-data)) ERR-NOT-AUTHORIZED)

    ;; Update maintenance mode
    (map-set space-availability
      { space-id: space-id }
      (merge availability { maintenance-mode: maintenance })
    )

    (ok true)
  )
)

(define-public (deactivate-space (space-id uint))
  (let (
    (space-data (unwrap! (get-space space-id) ERR-SPACE-NOT-FOUND))
  )
    ;; Check authorization
    (asserts! (is-eq tx-sender (get owner space-data)) ERR-NOT-AUTHORIZED)

    ;; Update status
    (map-set parking-spaces
      { space-id: space-id }
      (merge space-data {
        status: "inactive",
        updated-at: block-height
      })
    )

    ;; Set unavailable
    (map-set space-availability
      { space-id: space-id }
      {
        is-available: false,
        available-from: u0,
        available-until: u0,
        maintenance-mode: false
      }
    )

    (ok true)
  )
)

(define-public (update-space-stats
  (space-id uint)
  (booking-revenue uint)
  (new-rating uint)
)
  (let (
    (space-data (unwrap! (get-space space-id) ERR-SPACE-NOT-FOUND))
    (current-stats (get-space-stats space-id))
  )
    ;; This function should only be called by the reservations contract
    ;; For now, we'll allow the space owner to update stats
    (asserts! (is-eq tx-sender (get owner space-data)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rating u5) ERR-INVALID-INPUT)

    ;; Calculate new average rating
    (let (
      (total-reviews (get review-count current-stats))
      (current-rating (get rating current-stats))
      (new-review-count (+ total-reviews u1))
      (new-avg-rating (if (is-eq total-reviews u0)
        new-rating
        (/ (+ (* current-rating total-reviews) new-rating) new-review-count)
      ))
    )
      ;; Update stats
      (map-set space-stats
        { space-id: space-id }
        {
          total-bookings: (+ (get total-bookings current-stats) u1),
          total-revenue: (+ (get total-revenue current-stats) booking-revenue),
          rating: new-avg-rating,
          review-count: new-review-count
        }
      )

      (ok true)
    )
  )
)
