(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SENTENCE_TOO_LONG (err u101))
(define-constant ERR_SENTENCE_TOO_SHORT (err u102))
(define-constant ERR_STORY_NOT_FOUND (err u103))
(define-constant ERR_INVALID_STORY_ID (err u104))
(define-constant ERR_EMPTY_SENTENCE (err u105))

(define-constant MAX_SENTENCE_LENGTH u280)
(define-constant MIN_SENTENCE_LENGTH u5)
(define-constant MAX_STORIES u1000)

(define-data-var story-counter uint u0)
(define-data-var total-sentences uint u0)

(define-map stories
    { story-id: uint }
    {
        title: (string-ascii 100),
        creator: principal,
        sentence-count: uint,
        created-at: uint,
        is-active: bool
    }
)

(define-map story-sentences
    { story-id: uint, sentence-id: uint }
    {
        content: (string-utf8 280),
        author: principal,
        added-at: uint
    }
)

(define-map user-contributions
    { user: principal, story-id: uint }
    { sentence-count: uint }
)

(define-map user-stats
    { user: principal }
    {
        total-sentences: uint,
        stories-created: uint,
        stories-contributed: uint
    }
)

(define-read-only (get-story-counter)
    (var-get story-counter)
)

(define-read-only (get-total-sentences)
    (var-get total-sentences)
)

(define-read-only (get-story (story-id uint))
    (map-get? stories { story-id: story-id })
)

(define-read-only (get-sentence (story-id uint) (sentence-id uint))
    (map-get? story-sentences { story-id: story-id, sentence-id: sentence-id })
)

(define-read-only (get-user-contributions (user principal) (story-id uint))
    (default-to 
        { sentence-count: u0 }
        (map-get? user-contributions { user: user, story-id: story-id })
    )
)

(define-read-only (get-user-stats (user principal))
    (default-to
        { total-sentences: u0, stories-created: u0, stories-contributed: u0 }
        (map-get? user-stats { user: user })
    )
)

(define-read-only (get-story-sentences (story-id uint) (start uint) (limit uint))
    (let
        (
            (story-data (unwrap! (get-story story-id) (err ERR_STORY_NOT_FOUND)))
            (sentence-count (get sentence-count story-data))
            (end (if (> (+ start limit) sentence-count) sentence-count (+ start limit)))
        )
        (ok {
            story: story-data,
            sentences: (map get-sentence-by-index (generate-sequence start end)),
            total-sentences: sentence-count
        })
    )
)

(define-private (get-sentence-by-index (index uint))
    (get-sentence (var-get story-counter) index)
)

(define-private (generate-sequence (start uint) (end uint))
    (if (<= start end)
        (unwrap-panic (as-max-len? (list start) u100))
        (list)
    )
)

(define-read-only (get-latest-stories (limit uint))
    (let
        (
            (current-counter (var-get story-counter))
            (start (if (> current-counter limit) (- current-counter limit) u0))
        )
        (ok (map get-story-by-id (generate-story-ids start current-counter)))
    )
)

(define-private (get-story-by-id (story-id uint))
    (get-story story-id)
)

(define-private (generate-story-ids (start uint) (end uint))
    (if (<= start end)
        (unwrap-panic (as-max-len? (list start) u100))
        (list)
    )
)

(define-public (create-story (title (string-ascii 100)))
    (let
        (
            (new-story-id (+ (var-get story-counter) u1))
            (current-block stacks-block-height)
        )
        (asserts! (> (len title) u0) ERR_EMPTY_SENTENCE)
        (asserts! (<= new-story-id MAX_STORIES) ERR_INVALID_STORY_ID)
        
        (map-set stories
            { story-id: new-story-id }
            {
                title: title,
                creator: tx-sender,
                sentence-count: u0,
                created-at: current-block,
                is-active: true
            }
        )
        
        (var-set story-counter new-story-id)
        (update-user-story-creation tx-sender)
        (ok new-story-id)
    )
)

(define-public (add-sentence (story-id uint) (sentence (string-utf8 280)))
    (let
        (
            (story-data (unwrap! (get-story story-id) ERR_STORY_NOT_FOUND))
            (sentence-len (len sentence))
            (new-sentence-id (+ (get sentence-count story-data) u1))
            (current-block stacks-block-height)
        )
        (asserts! (get is-active story-data) ERR_UNAUTHORIZED)
        (asserts! (>= sentence-len MIN_SENTENCE_LENGTH) ERR_SENTENCE_TOO_SHORT)
        (asserts! (<= sentence-len MAX_SENTENCE_LENGTH) ERR_SENTENCE_TOO_LONG)
        
        (map-set story-sentences
            { story-id: story-id, sentence-id: new-sentence-id }
            {
                content: sentence,
                author: tx-sender,
                added-at: current-block
            }
        )
        
        (map-set stories
            { story-id: story-id }
            (merge story-data { sentence-count: new-sentence-id })
        )
        
        (var-set total-sentences (+ (var-get total-sentences) u1))
        (update-user-contributions tx-sender story-id)
        (update-user-sentence-stats tx-sender)
        (ok new-sentence-id)
    )
)

(define-public (toggle-story-status (story-id uint))
    (let
        (
            (story-data (unwrap! (get-story story-id) ERR_STORY_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get creator story-data)) ERR_UNAUTHORIZED)
        
        (map-set stories
            { story-id: story-id }
            (merge story-data { is-active: (not (get is-active story-data)) })
        )
        (ok (not (get is-active story-data)))
    )
)

(define-private (update-user-contributions (user principal) (story-id uint))
    (let
        (
            (current-contributions (get-user-contributions user story-id))
            (new-count (+ (get sentence-count current-contributions) u1))
        )
        (map-set user-contributions
            { user: user, story-id: story-id }
            { sentence-count: new-count }
        )
        (if (is-eq (get sentence-count current-contributions) u0)
            (update-user-story-contribution user)
            true
        )
    )
)

(define-private (update-user-sentence-stats (user principal))
    (let
        (
            (current-stats (get-user-stats user))
            (new-sentence-count (+ (get total-sentences current-stats) u1))
        )
        (map-set user-stats
            { user: user }
            (merge current-stats { total-sentences: new-sentence-count })
        )
    )
)

(define-private (update-user-story-creation (user principal))
    (let
        (
            (current-stats (get-user-stats user))
            (new-created-count (+ (get stories-created current-stats) u1))
        )
        (map-set user-stats
            { user: user }
            (merge current-stats { stories-created: new-created-count })
        )
    )
)

(define-private (update-user-story-contribution (user principal))
    (let
        (
            (current-stats (get-user-stats user))
            (new-contributed-count (+ (get stories-contributed current-stats) u1))
        )
        (map-set user-stats
            { user: user }
            (merge current-stats { stories-contributed: new-contributed-count })
        )
    )
)