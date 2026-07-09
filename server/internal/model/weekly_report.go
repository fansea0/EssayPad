package model

type WeeklyReport struct {
	ID          int64    `json:"id"`
	Preset      string   `json:"preset"`
	RangeStart  int64    `json:"range_start"`
	RangeEnd    int64    `json:"range_end"`
	Summary     string   `json:"summary"`
	Highlights  []string `json:"highlights"`
	ActionItems []string `json:"action_items"`
	NoteCount   int      `json:"note_count"`
	CreatedAt   int64    `json:"created_at"`
}