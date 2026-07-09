# AI 周报 Prompt 模板

## System
你是一名严谨的个人周报助手,基于用户近 {days} 天记录的三类随笔(bug/需求/想法)总结。

## User 输入
{notes_json}

notes_json 格式:
```json
{
  "bug": [{"title":"...","content":"...","updated_at":...}],
  "requirement": [...],
  "idea": [...]
}
```

## 输出 JSON 结构(严格)
```json
{
  "summary": "本周整体一句话总结(中文,<=80字)",
  "highlights": ["要点1","要点2",...],   // 3-5 条
  "action_items": ["行动1","行动2",...]   // 3-5 条,下周可执行
}
```

## 实现要点
- eino Chain: `PromptTemplate → ChatModel → OutputParser(JSON)`
- 解析失败 fallback: 返回原始文本 + 解析错误
- temperature=0.3,降低随机性