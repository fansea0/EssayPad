package model

const (
	DiaryMoodNone    = 0
	DiaryMoodHappy   = 1
	DiaryMoodCalm    = 2
	DiaryMoodDown    = 3
	DiaryMoodAnxious = 4
)

const (
	DiaryStatusNone      = 0
	DiaryStatusExcellent = 1
	DiaryStatusGood      = 2
	DiaryStatusNormal    = 3
	DiaryStatusPoor      = 4
	DiaryStatusBad       = 5
)

const (
	DiaryActivityNone   = 0
	DiaryActivityWork   = 1
	DiaryActivityStudy  = 2
	DiaryActivityTravel = 3
	DiaryActivityRest   = 4
	DiaryActivityGame   = 5
)

type DiaryEntry struct {
	ID        int64  `json:"id"`
	UserID    int64  `json:"user_id"`
	DiaryDate int64  `json:"diary_date"`
	Title     string `json:"title"`
	Content   string `json:"content"`
	Mood      int    `json:"mood"`
	Status    int    `json:"status"`
	Activity  int    `json:"activity"`
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
}

func ValidDiaryMood(v int) bool {
	return v >= DiaryMoodNone && v <= DiaryMoodAnxious
}

func ValidDiaryStatus(v int) bool {
	return v >= DiaryStatusNone && v <= DiaryStatusBad
}

func ValidDiaryActivity(v int) bool {
	return v >= DiaryActivityNone && v <= DiaryActivityGame
}
