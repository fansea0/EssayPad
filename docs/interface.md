# 接口协议

Base URL: `http://127.0.0.1:18888`

统一响应:
```json
{ "code": 0, "msg": "ok", "data": { ... } }
```
`code != 0` 表示错误。

## 1. 创建随笔
- `POST /api/v1/notes`
- req:
```json
{ "category": 1, "title": "登录页 500", "content": "..." }
```
- resp 200:
```json
{ "code":0,"msg":"ok","data":{ "id":123, "category":1, "title":"...","content":"...","created_at":1718000000,"updated_at":1718000000 } }
```

## 2. 随笔列表
- `GET /api/v1/notes?category=1&page=1&page_size=20`
- resp 200:
```json
{ "code":0,"data":{ "total":42, "list":[ ...note ] } }
```

## 3. 更新随笔
- `PUT /api/v1/notes/:id`
- req: 字段可选
```json
{ "title":"...", "content":"...", "category":2 }
```

## 4. 删除随笔(软删)
- `DELETE /api/v1/notes/:id`
- resp 200: `{ "code":0, "msg":"ok" }`

## 5. 随笔详情
- `GET /api/v1/notes/:id`

## 6. AI 周复盘
- `POST /api/v1/weekly/generate`
- req: `{ "preset":"week", "force":false }`
- resp 200:
```json
{ "code":0, "data":{ "id":12,"reflection_json":"{...}","note_count":18,"created_at":1718000000 } }
```

`reflection_json` 结构：`greeting`、`one_liner`、`story`、`observations`、`growth`、`suggestions`、`suggested_questions`。服务端从笔记、日记和任务的时间窗口中检索后生成；为兼容历史数据，`story` 支持字符串或字符串数组。

## 7. 周复盘对话
- `GET /api/v1/weekly/:id/messages`
- resp 200:
```json
{ "code":0,"data":{ "list":[{"id":1,"report_id":12,"role":1,"content":"...","created_at":1718000000}] } }
```

- `POST /api/v1/weekly/:id/messages`
- req: `{ "content":"我下周应该先做什么？" }`
- resp 200:
```json
{ "code":0,"data":{ "user_message":{...},"assistant_message":{...} } }
```

## 8. AI 配置

- `GET /api/v1/ai-config`
- resp 200：API Key 仅返回是否已配置，不返回原文。
```json
{ "code":0,"data":{ "base_url":"https://example.com/v1","model":"model-name","has_api_key":true } }
```

- `PUT /api/v1/ai-config`
- req：不传或传 `null` 表示保留原 Key，空字符串表示清除，非空字符串表示替换。
```json
{ "base_url":"https://example.com/v1","api_key":"new-key","model":"model-name" }
```

配置保存在通用 `app_settings` 表中，以 `scope + setting_key` 唯一定位。`setting_value` 支持普通字符串或 JSON，`is_secret=1` 表示敏感配置；敏感值不会出现在查询接口和请求日志中。

## 错误码
- 400 参数错误
- 404 不存在
- 500 服务异常
- 1001 AI 调用失败
