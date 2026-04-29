# SMTP Configuration Settings — Device Handoff Document

> **Client:** [Client Name]
> **Deployed By:** [Your Name], Azure Innovators
> **Deployment Date:** [Date]
> **Secret Expiration:** [Date]

---

## SMTP Settings

| Setting | Value |
|---|---|
| **SMTP Server** | `smtp.azurecomm.net` |
| **Port** | `587` |
| **Encryption** | `STARTTLS` |
| **Authentication** | Username and Password |
| **Username** | `[custom-smtp-username]` |
| **Password** | `[Stored securely — see credential vault]` |

## Authorized Sender Addresses

| MailFrom Address | Display Name | Use Case |
|---|---|---|
| `DoNotReply@[domain]` | Do Not Reply | Default system messages |
| `scanner@[domain]` | Scanner | Copier/printer scan-to-email |
| `alerts@[domain]` | System Alerts | Monitoring and alerting |

## Important Notes

- The **From Address** on each device must exactly match one of the authorized sender addresses above.
- The client secret (password) expires on **[expiration date]**. Set a reminder to rotate it 30 days before expiration.
- ACS only accepts connections via the DNS hostname `smtp.azurecomm.net` — IP addresses will not work.
- If authentication fails after a password change, allow up to 10 minutes for propagation.

## Support

- **Azure Innovators:** [www.azureinnovators.com](https://www.azureinnovators.com)
- **Contact:** [https://azureinnovators.com/contact-us/](https://azureinnovators.com/contact-us/)
