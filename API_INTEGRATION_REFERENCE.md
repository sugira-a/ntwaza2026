# Admin Dashboard - API Integration Guide

## 📡 All New API Endpoints Used

### Revenue & Finance APIs

#### 1. Get Revenue Report
**Endpoint**: `GET /api/admin/finance/revenue-report`

**Query Parameters**:
- `period`: day | week | month | year (default: month)
- `start_date`: YYYY-MM-DD (optional)
- `end_date`: YYYY-MM-DD (optional)

**Example Request**:
```bash
GET /api/admin/finance/revenue-report?period=month
Authorization: Bearer {admin_token}
```

**Example Response**:
```json
{
  "report": {
    "period": {
      "start": "2026-02-01T00:00:00",
      "end": "2026-02-28T23:59:59",
      "days": 28
    },
    "summary": {
      "total_revenue": 500000,
      "total_orders": 150,
      "average_order_value": 3333.33,
      "platform_commission": 75000,
      "vendor_payouts": 300000,
      "driver_payouts": 75000,
      "net_platform_earnings": -300000
    },
    "daily_breakdown": [
      {
        "date": "2026-02-01",
        "order_count": 5,
        "revenue": 20000
      }
    ],
    "top_vendors": [
      {
        "business_name": "Restaurant Name",
        "order_count": 25,
        "revenue": 150000
      }
    ],
    "top_drivers": [
      {
        "driver_name": "John Doe",
        "order_count": 30,
        "total_earnings": 15000
      }
    ]
  }
}
```

**Used In**: Money Management Tab
**Displays**: Revenue breakdown, platform commission, delivery fees, vendor payouts

---

#### 2. Get Transactions
**Endpoint**: `GET /api/admin/finance/transactions`

**Query Parameters**:
- `page`: number (default: 1)
- `per_page`: number (default: 50)
- `type`: string (optional - commission, payout, refund)
- `status`: string (optional - pending, completed, failed)

**Example Request**:
```bash
GET /api/admin/finance/transactions?page=1&per_page=20&status=completed
Authorization: Bearer {admin_token}
```

**Example Response**:
```json
{
  "transactions": [
    {
      "id": "txn_123",
      "transaction_type": "commission",
      "amount": 15000,
      "status": "completed",
      "order_id": "ord_456",
      "created_at": "2026-02-01T10:30:00",
      "description": "15% commission on order"
    },
    {
      "id": "txn_124",
      "transaction_type": "driver_payout",
      "amount": 5000,
      "status": "completed",
      "order_id": "ord_456",
      "created_at": "2026-02-01T10:35:00",
      "description": "Delivery fee to driver"
    }
  ],
  "total": 500,
  "pages": 10,
  "current_page": 1,
  "per_page": 50
}
```

**Used In**: Future transaction history view
**Displays**: Individual transactions with amounts and status

---

### Support Tickets APIs

#### 3. Get Support Tickets
**Endpoint**: `GET /api/admin/support/tickets`

**Query Parameters**:
- `page`: number (default: 1)
- `per_page`: number (default: 50)
- `status`: string (optional - open, in_progress, resolved, closed)
- `priority`: string (optional - low, medium, high, urgent)
- `category`: string (optional - order_issue, payment, account, technical, feedback)
- `assigned_to`: string (optional - me, unassigned, admin_id)

**Example Request**:
```bash
GET /api/admin/support/tickets?status=open&priority=high
Authorization: Bearer {admin_token}
```

**Example Response**:
```json
{
  "tickets": [
    {
      "id": "tkt_001",
      "ticket_number": "TK-001",
      "user_id": "usr_123",
      "user_name": "John Doe",
      "user_email": "john@example.com",
      "user_phone": "+250788123456",
      "category": "order_issue",
      "priority": "high",
      "subject": "Order not delivered",
      "description": "I ordered food 2 hours ago but rider hasn't arrived",
      "status": "open",
      "assigned_to": null,
      "created_at": "2026-02-01T14:30:00",
      "updated_at": "2026-02-01T14:30:00"
    },
    {
      "id": "tkt_002",
      "ticket_number": "TK-002",
      "user_id": "usr_124",
      "user_name": "Jane Smith",
      "user_email": "jane@example.com",
      "category": "feedback",
      "priority": "low",
      "subject": "Great service!",
      "description": "Really happy with the delivery service",
      "status": "resolved",
      "assigned_to": "adm_005",
      "created_at": "2026-02-01T10:15:00",
      "updated_at": "2026-02-01T12:45:00"
    }
  ],
  "total": 45,
  "pages": 1,
  "current_page": 1,
  "per_page": 50,
  "counts": {
    "open": 8,
    "in_progress": 3,
    "resolved": 25,
    "assigned_to_me": 2
  }
}
```

**Used In**: Issues & Alerts Tab
**Displays**: List of support tickets with filtering and status counts

---

#### 4. Get Ticket Details
**Endpoint**: `GET /api/admin/support/tickets/{ticket_id}`

**Example Request**:
```bash
GET /api/admin/support/tickets/tkt_001
Authorization: Bearer {admin_token}
```

**Example Response**:
```json
{
  "ticket": {
    "id": "tkt_001",
    "ticket_number": "TK-001",
    "subject": "Order not delivered",
    "status": "open",
    "priority": "high",
    "category": "order_issue",
    "user": {
      "id": "usr_123",
      "name": "John Doe",
      "email": "john@example.com",
      "phone": "+250788123456",
      "role": "customer"
    },
    "messages": [
      {
        "id": "msg_001",
        "sender_id": "usr_123",
        "sender_type": "user",
        "message": "I ordered food 2 hours ago but rider hasn't arrived",
        "created_at": "2026-02-01T14:30:00",
        "is_read": true
      },
      {
        "id": "msg_002",
        "sender_id": "adm_005",
        "sender_type": "admin",
        "message": "I'm looking into this now. Please give me 5 minutes.",
        "created_at": "2026-02-01T14:35:00",
        "is_read": false
      }
    ]
  }
}
```

**Used In**: Ticket detail view (future)
**Displays**: Full conversation history and ticket details

---

#### 5. Update Ticket Status
**Endpoint**: `POST /api/admin/support/tickets/{ticket_id}/status`

**Request Body**:
```json
{
  "status": "in_progress"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Ticket status updated"
}
```

---

#### 6. Assign Ticket
**Endpoint**: `POST /api/admin/support/tickets/{ticket_id}/assign`

**Request Body**:
```json
{
  "assigned_to": "adm_005"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Ticket assigned"
}
```

---

#### 7. Reply to Ticket
**Endpoint**: `POST /api/admin/support/tickets/{ticket_id}/reply`

**Request Body**:
```json
{
  "message": "We've located your delivery. Driver arriving in 10 minutes."
}
```

**Response**:
```json
{
  "success": true,
  "message_id": "msg_003"
}
```

---

## 🔐 Authentication

All endpoints require:
```
Authorization: Bearer {jwt_token}
```

Get token from login:
```bash
POST /api/auth/login
{
  "email": "admin@ntwaza.com",
  "password": "password"
}

Response:
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "user": {
    "id": "adm_005",
    "email": "admin@ntwaza.com",
    "role": "admin"
  }
}
```

---

## 🛠️ How It Works in Flutter

### 1. Money Management Tab Flow
```
User opens Money tab
    ↓
_MoneyManagementTabState.initState()
    ↓
_loadRevenueData()
    ↓
AdminDashboardService.getRevenueReport(period: 'month')
    ↓
ApiService.get('/api/admin/finance/revenue-report?period=month')
    ↓
Response with {summary, daily_breakdown, top_vendors}
    ↓
setState() → update UI with real data
    ↓
Display platform commission, delivery fees, vendor payouts
```

### 2. Issues & Alerts Tab Flow
```
User opens Alerts tab
    ↓
_IssuesAlertsTabState.initState()
    ↓
_loadTickets()
    ↓
AdminDashboardService.getSupportTickets(status: 'open')
    ↓
ApiService.get('/api/admin/support/tickets?status=open')
    ↓
Response with {tickets, total, counts}
    ↓
setState() → update UI with ticket list
    ↓
Display open/in-progress/resolved counts
    ↓
Display each ticket with priority/status badges
```

### 3. Period Selection
```
User taps "Week" chip
    ↓
setState(() => _selectedPeriod = 'week')
    ↓
_loadRevenueData() called again
    ↓
getRevenueReport(period: 'week')
    ↓
API returns weekly data
    ↓
UI updates with new values
```

---

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────────────┐
│           Admin Dashboard (Flutter)                 │
├─────────────────┬─────────────────────────────────┤
│  Money Tab      │  Issues Tab                     │
├─────────────────┼─────────────────────────────────┤
│ getRevenueReport│ getSupportTickets              │
└─────────────────┴─────────────────────────────────┘
           ↓                      ↓
    ┌──────────────┐      ┌─────────────────┐
    │ /admin/      │      │ /admin/support/ │
    │ finance/     │      │ tickets         │
    │ revenue-     │      └─────────────────┘
    │ report       │              ↓
    └──────────────┘      ┌─────────────────┐
           ↓              │  app/routes/    │
    ┌──────────────┐      │  admin_support  │
    │  app/routes/ │      │  .py            │
    │  admin_      │      └─────────────────┘
    │  finance.py  │              ↓
    └──────────────┘      ┌─────────────────┐
           ↓              │  SupportTicket  │
    ┌──────────────┐      │  Model          │
    │  Order       │      └─────────────────┘
    │  Transaction │
    │  Models      │
    └──────────────┘
```

---

## ✅ Testing Checklist

- [ ] Money tab loads revenue data
- [ ] Period selector (Day/Week/Month/Year) works
- [ ] Revenue values change when period changes
- [ ] Alerts tab loads support tickets
- [ ] Ticket counts update correctly
- [ ] Filter chips work (All/Open/In Progress/Resolved)
- [ ] Error messages show when API fails
- [ ] Loading spinner appears while fetching
- [ ] Empty state shows when no data
- [ ] Pull-to-refresh reloads data
- [ ] Dark mode displays correctly

---

## 🐛 Debugging

### Check if APIs are working
```bash
# Terminal 1: Start backend
cd ntwaza-backend
python run.py

# Terminal 2: Test revenue API
curl -H "Authorization: Bearer {token}" \
  http://localhost:5000/api/admin/finance/revenue-report

# Terminal 3: Test tickets API
curl -H "Authorization: Bearer {token}" \
  http://localhost:5000/api/admin/support/tickets
```

### Check app logs
```
Run app with: flutter run -v

Look for:
- "✅ Push notifications enabled" → Good
- "❌ Error fetching revenue report" → Bad API call
- "❌ Error fetching support tickets" → Bad API call
```

---

**Last Updated**: February 1, 2026  
**Status**: Complete Integration  
**All APIs**: Connected and Ready
