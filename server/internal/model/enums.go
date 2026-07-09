package model

const (
	CategoryBug         = 1
	CategoryRequirement = 2
	CategoryIdea        = 3
	CategoryDraft       = 4
)

func ValidCategory(c int) bool {
	return c == CategoryBug || c == CategoryRequirement || c == CategoryIdea || c == CategoryDraft
}

func CategoryName(c int) string {
	switch c {
	case CategoryBug:
		return "bug"
	case CategoryRequirement:
		return "requirement"
	case CategoryIdea:
		return "idea"
	case CategoryDraft:
		return "draft"
	}
	return "unknown"
}
