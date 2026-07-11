package ai

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"essaypad/internal/model"
)

type groupedNotes struct {
	Bug         []*model.Note `json:"bug"`
	Requirement []*model.Note `json:"requirement"`
	Idea        []*model.Note `json:"idea"`
}

type TaskBrief struct {
	Title       string `json:"title"`
	Progress    int    `json:"progress,omitempty"`
	DueAt       string `json:"due,omitempty"`
	CompletedAt string `json:"completed_at,omitempty"`
	OverdueDays int    `json:"overdue_days,omitempty"`
}

type TaskSummary struct {
	Active    []TaskBrief `json:"active"`
	Completed []TaskBrief `json:"completed"`
	Overdue   []TaskBrief `json:"overdue"`
}

type ReflectionInput struct {
	Notes   []*model.Note
	Diaries []*model.DiaryEntry
	Tasks   TaskSummary
	Days    int
}

func groupByCategory(notes []*model.Note) groupedNotes {
	var g groupedNotes
	for _, n := range notes {
		switch n.Category {
		case model.CategoryBug:
			g.Bug = append(g.Bug, n)
		case model.CategoryRequirement:
			g.Requirement = append(g.Requirement, n)
		case model.CategoryIdea:
			g.Idea = append(g.Idea, n)
		}
	}
	return g
}

func systemPrompt(days int) string {
	return fmt.Sprintf("你是一名严谨的个人周报助手,基于用户近 %d 天的随笔(bug/需求/想法)和任务(进行中/已完成/延期)总结。已完成的任务列入 highlights,延期或未完成的任务列入 action_items。严格按要求的 JSON 结构输出,不要有任何额外文字。", days)
}

func buildWeeklyPrompt(g groupedNotes, tasks TaskSummary, days int) string {
	payload, _ := json.MarshalIndent(struct {
		Notes groupedNotes `json:"notes"`
		Tasks TaskSummary  `json:"tasks"`
	}{g, tasks}, "", "  ")
	return fmt.Sprintf("以下是用户近 %d 天的随笔和任务(JSON 格式):\n%s\n\n请输出严格 JSON(无 markdown 围栏):\n{\n  \"summary\": \"本周整体一句话总结(中文,<=80字)\",\n  \"highlights\": [\"要点1\",\"要点2\"],\n  \"action_items\": [\"行动1,如果是任务则前缀加[任务],如果是笔记则前缀加[笔记]\"]\n}", days, string(payload))
}

func parseWeekly(content string) (*model.WeeklyReport, error) {
	content = strings.TrimSpace(content)
	content = strings.TrimPrefix(content, "```json")
	content = strings.TrimPrefix(content, "```")
	content = strings.TrimSuffix(content, "```")
	content = strings.TrimSpace(content)

	var raw struct {
		Summary     string   `json:"summary"`
		Highlights  []string `json:"highlights"`
		ActionItems []string `json:"action_items"`
	}
	if err := json.Unmarshal([]byte(content), &raw); err != nil {
		return &model.WeeklyReport{
			Summary:     "AI 返回内容解析失败,原始内容:",
			Highlights:  []string{content},
			ActionItems: []string{},
			CreatedAt:   time.Now().Unix(),
		}, nil
	}
	return &model.WeeklyReport{
		Summary:     raw.Summary,
		Highlights:  raw.Highlights,
		ActionItems: raw.ActionItems,
		CreatedAt:   time.Now().Unix(),
	}, nil
}

func reflectionSystemPrompt(days int) string {
	return fmt.Sprintf("你是熟悉用户记录的真诚朋友，不是效率教练。只能根据用户近 %d 天的笔记、日记与任务分析，不要编造事实。表达具体、温和、有自己的观察，避免空泛鼓励、官话和说教。严格输出 JSON，不要 markdown 围栏。", days)
}

func buildReflectionPrompt(input ReflectionInput) string {
	payload, _ := json.MarshalIndent(struct {
		Notes   []*model.Note       `json:"notes"`
		Diaries []*model.DiaryEntry `json:"diaries"`
		Tasks   TaskSummary         `json:"tasks"`
	}{input.Notes, input.Diaries, input.Tasks}, "", "  ")
	return fmt.Sprintf("以下是用户近 %d 天的记录：\n%s\n\n输出 JSON：\n{\n  \"greeting\": \"一句自然问候\",\n  \"one_liner\": \"有记忆点的一句话，不超过35字\",\n  \"story\": \"2到3段本周故事，每段不超过80字\",\n  \"observations\": [\"有证据的观察，最多3条\"],\n  \"growth\": [\"真实成长，最多3条\"],\n  \"suggestions\": [\"小而具体的建议，最多3条\"],\n  \"suggested_questions\": [\"用户可能想继续问的自然问题，2到3条\"]\n}", input.Days, string(payload))
}

func parseReflection(content string) (*model.WeeklyReflection, error) {
	content = strings.TrimSpace(strings.TrimSuffix(strings.TrimPrefix(strings.TrimPrefix(content, "```json"), "```"), "```"))
	var reflection model.WeeklyReflection
	if err := json.Unmarshal([]byte(content), &reflection); err != nil {
		return nil, fmt.Errorf("parse reflection: %w", err)
	}
	return &reflection, nil
}

func reflectionChatSystemPrompt(reflectionJSON string) string {
	return "你是用户的周复盘伙伴。请基于以下本周复盘继续自然对话：像熟悉用户近况的朋友一样回应，少用结论和口号；先回应用户的真实感受，再给具体观察或一个可执行的小建议。不要为了延续聊天而反问，不要用问句收尾。使用短段落，必要时用 markdown 列表；可以自然使用 1 到 2 个 emoji，不编造事实。\n\n本周复盘：\n" + reflectionJSON
}

// FormatDueAt 把秒级时间戳格式化为 "YYYY-MM-DD"(本地时区)
func FormatDueAt(ts int64) string {
	if ts <= 0 {
		return ""
	}
	t := time.Unix(ts, 0)
	return t.Format("2006-01-02")
}

// FormatCompletedAt 把秒级时间戳格式化为 "YYYY-MM-DD HH:MM"
func FormatCompletedAt(ts int64) string {
	if ts <= 0 {
		return ""
	}
	t := time.Unix(ts, 0)
	return t.Format("2006-01-02 15:04")
}

// OverdueDays 计算 due_at 相对今天 0 点的过期天数(向下取整)
func OverdueDays(dueAt int64) int {
	if dueAt <= 0 {
		return 0
	}
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()).Unix()
	if dueAt >= todayStart {
		return 0
	}
	return int((todayStart - dueAt) / 86400)
}

// BuildTaskSummary 把 task 三元组转成 AI 用的 brief(本地时区格式化时间)
func BuildTaskSummary(active, completed, overdue []*model.Task) TaskSummary {
	s := TaskSummary{}
	for _, t := range active {
		s.Active = append(s.Active, TaskBrief{
			Title:    t.Title,
			Progress: t.Progress,
			DueAt:    FormatDueAt(t.DueAt),
		})
	}
	for _, t := range completed {
		s.Completed = append(s.Completed, TaskBrief{
			Title:       t.Title,
			CompletedAt: FormatCompletedAt(t.CompletedAt),
		})
	}
	for _, t := range overdue {
		s.Overdue = append(s.Overdue, TaskBrief{
			Title:       t.Title,
			Progress:    t.Progress,
			DueAt:       FormatDueAt(t.DueAt),
			OverdueDays: OverdueDays(t.DueAt),
		})
	}
	return s
}
