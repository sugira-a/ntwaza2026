import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.utils import formataddr

class EmailService:
    def __init__(self, smtp_server, smtp_port, username, password):
        self.smtp_server = smtp_server
        self.smtp_port = smtp_port
        self.username = username
        self.password = password

    def send_email(self, recipient_email, subject, body):
        try:
            msg = MIMEMultipart()
            msg['From'] = formataddr(("Ntwaza", self.username))
            msg['To'] = recipient_email
            msg['Subject'] = subject

            msg.attach(MIMEText(body, 'plain'))

            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.username, self.password)
                server.sendmail(self.username, recipient_email, msg.as_string())

            print("Email sent successfully to", recipient_email)
        except Exception as e:
            print("Failed to send email:", str(e))

# Function to send OTP email for password reset
import os
def send_reset_email(recipient_email, otp):
    smtp_server = os.getenv('MAIL_SERVER', 'smtp.gmail.com')
    smtp_port = int(os.getenv('MAIL_PORT', 587))
    username = os.getenv('MAIL_USERNAME')
    password = os.getenv('MAIL_PASSWORD')
    subject = 'Ntwaza Password Reset OTP'
    body = f"Your OTP for password reset is: {otp}\nThis code will expire in 10 minutes."
    service = EmailService(smtp_server, smtp_port, username, password)
    service.send_email(recipient_email, subject, body)