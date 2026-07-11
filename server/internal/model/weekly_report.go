package model

type WeeklyReport struct {
	ID               int64    `json:"id"`
	Preset           string   `json:"preset"`
	RangeStart       int64    `json:"range_start"`
	RangeEnd         int64    `json:"range_end"`
	Summary          string   `json:"summary"`
	Highlights       []string `json:"highlights"`
	ActionItems      []string `json:"action_items"`
	NoteCount        int      `json:"note_count"`
	ReflectionJSON   string   `json:"reflection_json"`
	ResponseID       string   `json:"response_id"`
	ResponseExpireAt int64    `json:"response_expire_at"`
	CreatedAt        int64    `json:"created_at"`
}

const (
	WeeklyReflectionRoleUser = iota
	WeeklyReflectionRoleAssistant
)

type WeeklyReflectionMessage struct {
	ID                 int64  `json:"id"`
	ReportID           int64  `json:"report_id"`
	Role               int    `json:"role"`
	Content            string `json:"content"`
	ResponseID         string `json:"response_id"`
	PreviousResponseID string `json:"previous_response_id"`
	CreatedAt          int64  `json:"created_at"`
}

type WeeklyReflection struct {
	Greeting     string   `json:"greeting"`
	OneLiner     string   `json:"one_liner"`
	Story        string   `json:"story"`
	Observations []string `json:"observations"`
	Growth       []string `json:"growth"`
	Suggestions  []string `json:"suggestions"`
	SuggestedQuestions []string `json:"suggested_questions"`
}
