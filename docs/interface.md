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

## 6. AI 周报
- `POST /api/v1/weekly/generate`
- req: `{ "days": 7 }`  (可选,默认 7)
- resp 200:
```json
{ "code":0, "data":{ "summary":"...","highlights":[...],"action_items":[...],"generated_at":1718000000 } }
```

## 错误码
- 400 参数错误
- 404 不存在
- 500 服务异常
- 1001 AI 调用失败