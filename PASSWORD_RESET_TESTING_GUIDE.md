# Password Reset OTP - Quick Testing Guide

## Test Endpoints

### 1. Request Password Reset Code (Forgot Password)
```bash
curl -X POST http://localhost:5000/api/auth/reset-password-request \
  -H "Content-Type: application/json" \
  -d '{"email":"vendor@example.com"}'
```
**Expected Response:**
```json
{
  "success": true,
  "message": "If account exists, reset code sent to email"
}
```

### 2. Reset Password with Verification Code
```bash
curl -X POST http://localhost:5000/api/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{
    "email":"vendor@example.com",
    "verification_code":"123456",
    "new_password":"NewPassword123"
  }'
```
**Expected Response:**
```json
{
  "success": true,
  "message": "Password reset successful"
}
```

### 3. Request Password Change Code (Authenticated)
```bash
curl -X POST http://localhost:5000/api/auth/request-password-change-code \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt_token>" \
  -d '{"current_password":"CurrentPassword123"}'
```
**Expected Response:**
```json
{
  "success": true,
  "message": "Verification code sent to your email"
}
```

### 4. Change Password with Verification Code
```bash
curl -X POST http://localhost:5000/api/auth/verify-and-change-password \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt_token>" \
  -d '{
    "verification_code":"123456",
    "new_password":"NewPassword456"
  }'
```
**Expected Response:**
```json
{
  "success": true,
  "message": "Password changed successfully"
}
```

## Test Frontend

1. **Open Reset Page**
   - URL: `http://localhost:5000/static/reset-password.html`
   - Expected: Request form with email field visible

2. **Enter Email and Request Code**
   - Enter valid email address
   - Click "Send Verification Code"
   - Expected: Success message, form transitions to reset form

3. **Enter Code and New Password**
   - Check email for 6-digit code
   - Enter code in "Verification Code" field
   - Enter new password (8+ chars, uppercase, number)
   - Click "Reset Password"
   - Expected: Success message, password changed

## Test Email Template

### Verification Code Email
- **From:** credentials@example.com
- **Subject:** Your Ntwaza Verification Code
- **Template Elements:**
  - ✅ Red gradient header (FF6B6B → FF8E72)
  - ✅ "🔐 Verification Code" title
  - ✅ Large 48px monospace code with letter spacing
  - ✅ "Valid for 10 minutes" text
  - ✅ Security warning box (orange border)
  - ✅ Dark footer with support link
  - ✅ Plain text fallback version

## Error Scenarios

### Invalid Code
```bash
# Code that doesn't match
{
  "email":"user@example.com",
  "verification_code":"999999",  # Wrong code
  "new_password":"NewPass123"
}
```
**Response:** `400 Bad Request - "Invalid verification code"`

### Expired Code  
```bash
# Code generated >10 minutes ago
{
  "email":"user@example.com",
  "verification_code":"123456",  # Expired
  "new_password":"NewPass123"
}
```
**Response:** `400 Bad Request - "Verification code expired"`

### Weak Password
```bash
{
  "email":"user@example.com",
  "verification_code":"123456",
  "new_password":"weak"  # <8 chars
}
```
**Response:** `400 Bad Request - "Password must be at least 8 characters"`

### Password Reuse
```bash
{
  "email":"user@example.com",
  "verification_code":"123456",
  "new_password":"OldPassword123"  # Same as current
}
```
**Response:** `400 Bad Request - "New password cannot be same as current"`

## Files to Verify

### Backend Files
- ✅ `app/utils/password_codes.py` - OTP generation and validation
- ✅ `app/routes/auth.py` - Reset endpoints
- ✅ `app/routes/password_verification.py` - Change endpoints
- ✅ `app/services/email_service.py` - Professional email template

### Frontend Files
- ✅ `static/reset-password.html` - Request and reset forms

## Live Email Testing

To test actual email sending during development:

1. **Check environment variables:**
   ```
   MAIL_SERVER=smtp.gmail.com
   MAIL_PORT=587
   MAIL_USE_TLS=true
   MAIL_USERNAME=your-email@gmail.com
   MAIL_PASSWORD=your-app-password
   ```

2. **Create test account:**
   ```bash
   python create_admin.py
   # or use existing vendor/customer account
   ```

3. **Request reset code:**
   ```bash
   curl -X POST http://localhost:5000/api/auth/reset-password-request \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com"}'
   ```

4. **Check email inbox:**
   - Verify email arrives within seconds
   - Verify template renders correctly
   - Verify code is readable
   - Click support link

## Troubleshooting

### Email not being sent
- Check `MAIL_USERNAME` and `MAIL_PASSWORD` in config
- Check SMTP server is accessible (telnet smtp.gmail.com 587)
- Check app logs for SMTP errors
- Try sending test email from Flask shell

### Code not working
- Verify code was generated (check backend logs)
- Verify code matches exactly (timestamps matter)
- Verify code hasn't expired (10 minute window)
- Check that email matches exactly

### Frontend form not submitting
- Open browser console (F12) - check for JavaScript errors
- Verify API endpoint URLs are correct
- Check network tab for API response errors
- Verify backend is running on correct port

## Success Criteria

✅ Password reset works without needing email links
✅ OTP code valid for 10 minutes
✅ Password requires 8 chars, uppercase, number
✅ Password cannot be reused
✅ Email arrives in <5 seconds
✅ Email template has professional styling
✅ Works for all user roles (vendor, customer, admin, rider)
✅ Both web and API flows working

---

**Status:** All core functionality complete and tested locally.
**Next Steps:** Web portal integration and end-to-end testing.
