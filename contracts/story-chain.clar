(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SENTENCE_TOO_LONG (err u101))
(define-constant ERR_SENTENCE_TOO_SHORT (err u102))
(define-constant ERR_STORY_NOT_FOUND (err u103))
(define-constant ERR_INVALID_STORY_ID (err u104))
(define-constant ERR_EMPTY_SENTENCE (err u105))
(define-constant ERR_INSUFFICIENT_FUNDS (err u106))
(define-constant ERR_REWARD_TRANSFER_FAILED (err u107))
(define-constant ERR_ALREADY_VOTED (err u108))
(define-constant ERR_CANNOT_VOTE_OWN_CONTENT (err u109))

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
        is-active: bool,
        reward-per-sentence: uint,
        reward-pool: uint,
        total-votes: uint,
        story-score: int
    }
)

(define-map story-sentences
    { story-id: uint, sentence-id: uint }
    {
        content: (string-utf8 280),
        author: principal,
        added-at: uint,
        upvotes: uint,
        downvotes: uint,
        vote-score: int
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
        stories-contributed: uint,
        total-rewards-earned: uint,
        votes-cast: uint,
        votes-received: uint
    }
)

(define-map sentence-votes
    { voter: principal, story-id: uint, sentence-id: uint }
    { vote-type: bool }
)

(define-map story-votes
    { voter: principal, story-id: uint }
    { vote-type: bool }
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
        { total-sentences: u0, stories-created: u0, stories-contributed: u0, total-rewards-earned: u0, votes-cast: u0, votes-received: u0 }
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
                is-active: true,
                reward-per-sentence: u0,
                reward-pool: u0,
                total-votes: u0,
                story-score: 0
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
            (reward-amount (get reward-per-sentence story-data))
            (current-pool (get reward-pool story-data))
        )
        (asserts! (get is-active story-data) ERR_UNAUTHORIZED)
        (asserts! (>= sentence-len MIN_SENTENCE_LENGTH) ERR_SENTENCE_TOO_SHORT)
        (asserts! (<= sentence-len MAX_SENTENCE_LENGTH) ERR_SENTENCE_TOO_LONG)
        
        (map-set story-sentences
            { story-id: story-id, sentence-id: new-sentence-id }
            {
                content: sentence,
                author: tx-sender,
                added-at: current-block,
                upvotes: u0,
                downvotes: u0,
                vote-score: 0
            }
        )
        
        (if (and (> reward-amount u0) (>= current-pool reward-amount))
            (begin
                (unwrap! (stx-transfer? reward-amount (as-contract tx-sender) tx-sender) ERR_REWARD_TRANSFER_FAILED)
                (map-set stories
                    { story-id: story-id }
                    (merge story-data { 
                        sentence-count: new-sentence-id,
                        reward-pool: (- current-pool reward-amount)
                    })
                )
                (update-user-rewards tx-sender reward-amount)
            )
            (map-set stories
                { story-id: story-id }
                (merge story-data { sentence-count: new-sentence-id })
            )
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

(define-private (update-user-rewards (user principal) (reward-amount uint))
    (let
        (
            (current-stats (get-user-stats user))
            (new-rewards-total (+ (get total-rewards-earned current-stats) reward-amount))
        )
        (map-set user-stats
            { user: user }
            (merge current-stats { total-rewards-earned: new-rewards-total })
        )
    )
)

(define-public (fund-story-rewards (story-id uint) (amount uint))
    (let
        (
            (story-data (unwrap! (get-story story-id) ERR_STORY_NOT_FOUND))
            (current-pool (get reward-pool story-data))
        )
        (asserts! (is-eq tx-sender (get creator story-data)) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
        
        (unwrap! (stx-transfer? amount tx-sender (as-contract tx-sender)) ERR_REWARD_TRANSFER_FAILED)
        
        (map-set stories
            { story-id: story-id }
            (merge story-data { reward-pool: (+ current-pool amount) })
        )
        
        (ok (+ current-pool amount))
    )
)

(define-public (set-story-reward (story-id uint) (reward-per-sentence uint))
    (let
        (
            (story-data (unwrap! (get-story story-id) ERR_STORY_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get creator story-data)) ERR_UNAUTHORIZED)
        
        (map-set stories
            { story-id: story-id }
            (merge story-data { reward-per-sentence: reward-per-sentence })
        )
        
        (ok reward-per-sentence)
    )
)

(define-read-only (get-sentence-vote (voter principal) (story-id uint) (sentence-id uint))
    (map-get? sentence-votes { voter: voter, story-id: story-id, sentence-id: sentence-id })
)

(define-read-only (get-story-vote (voter principal) (story-id uint))
    (map-get? story-votes { voter: voter, story-id: story-id })
)

(define-public (vote-sentence (story-id uint) (sentence-id uint) (is-upvote bool))
    (let
        (
            (sentence-data (unwrap! (get-sentence story-id sentence-id) ERR_STORY_NOT_FOUND))
            (story-data (unwrap! (get-story story-id) ERR_STORY_NOT_FOUND))
            (sentence-author (get author sentence-data))
            (existing-vote (get-sentence-vote tx-sender story-id sentence-id))
            (current-upvotes (get upvotes sentence-data))
            (current-downvotes (get downvotes sentence-data))
            (current-score (get vote-score sentence-data))
        )
        (asserts! (not (is-eq tx-sender sentence-author)) ERR_CANNOT_VOTE_OWN_CONTENT)
        (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
        
        (let
            (
                (new-upvotes (if is-upvote (+ current-upvotes u1) current-upvotes))
                (new-downvotes (if is-upvote current-downvotes (+ current-downvotes u1)))
                (score-change (if is-upvote 1 -1))
                (new-score (+ current-score score-change))
            )
            (map-set sentence-votes
                { voter: tx-sender, story-id: story-id, sentence-id: sentence-id }
                { vote-type: is-upvote }
            )
            
            (map-set story-sentences
                { story-id: story-id, sentence-id: sentence-id }
                (merge sentence-data {
                    upvotes: new-upvotes,
                    downvotes: new-downvotes,
                    vote-score: new-score
                })
            )
            
            (update-story-vote-score story-id score-change)
            (update-user-vote-stats tx-sender sentence-author)
            (ok new-score)
        )
    )
)

(define-public (vote-story (story-id uint) (is-upvote bool))
    (let
        (
            (story-data (unwrap! (get-story story-id) ERR_STORY_NOT_FOUND))
            (story-creator (get creator story-data))
            (existing-vote (get-story-vote tx-sender story-id))
            (current-votes (get total-votes story-data))
            (current-score (get story-score story-data))
        )
        (asserts! (not (is-eq tx-sender story-creator)) ERR_CANNOT_VOTE_OWN_CONTENT)
        (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
        
        (let
            (
                (new-votes (+ current-votes u1))
                (score-change (if is-upvote 1 -1))
                (new-score (+ current-score score-change))
            )
            (map-set story-votes
                { voter: tx-sender, story-id: story-id }
                { vote-type: is-upvote }
            )
            
            (map-set stories
                { story-id: story-id }
                (merge story-data {
                    total-votes: new-votes,
                    story-score: new-score
                })
            )
            
            (update-user-vote-stats tx-sender story-creator)
            (ok new-score)
        )
    )
)

(define-private (update-story-vote-score (story-id uint) (score-change int))
    (let
        (
            (story-data (unwrap-panic (get-story story-id)))
            (current-score (get story-score story-data))
            (new-score (+ current-score score-change))
        )
        (map-set stories
            { story-id: story-id }
            (merge story-data { story-score: new-score })
        )
    )
)

(define-private (update-user-vote-stats (voter principal) (content-author principal))
    (let
        (
            (voter-stats (get-user-stats voter))
            (author-stats (get-user-stats content-author))
            (new-votes-cast (+ (get votes-cast voter-stats) u1))
            (new-votes-received (+ (get votes-received author-stats) u1))
        )
        (map-set user-stats
            { user: voter }
            (merge voter-stats { votes-cast: new-votes-cast })
        )
        (map-set user-stats
            { user: content-author }
            (merge author-stats { votes-received: new-votes-received })
        )
    )
)