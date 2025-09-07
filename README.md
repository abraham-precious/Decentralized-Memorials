📜 Decentralized Memorials – Permanent NFT Gravestones

Overview

This Clarity smart contract implements digital memorials as permanent NFTs on the Stacks blockchain. Each memorial serves as a tamper-proof gravestone that can include personal details, epitaphs, images, tributes, and donations.

The contract supports moderation, categories, version history, permissions, and donations, ensuring respectful, secure, and organized management of digital legacies.

✨ Features
🔐 Access Control & Roles

Contract Owner – full control, can manage admins and withdraw fees.

Admins – moderate memorials, update settings, archive content.

Owners – manage their memorials, grant/revoke permissions.

Collaborators – customizable edit, moderation, and viewing rights.

🪦 Memorial Management

Create a memorial with metadata (name, epitaph, birth/death dates, image, tags, category, location).

Requires creation fee (configurable, default 1 STX).

Memorials can be public or private.

Optional admin approval workflow before going live.

Support for versioning (edit epitaphs/images with change history).

Memorials can be archived by admins in emergencies.

💬 Tributes & Donations

Visitors can add tributes (messages, optional anonymity).

Tributes may include STX donations to memorial creators.

Maximum tributes per memorial is configurable.

🗂️ Categorization & Search

Create and manage categories for organization.

Tag memorials with up to 10 keywords.

(Stubs included for searching by creator, category, or tags).

🛡️ Moderation

Pending memorials go into a moderation queue.

Admins can approve or reject (with reason).

Audit trail includes timestamps and reviewer details.

⚙️ Config & Fees

Admins can update creation fees and toggle approval requirements.

Contract owner can withdraw accumulated fees.

📊 Data Structures

Memorials – stores core metadata and status.

Memorial Versions – historical edits for epitaphs/images.

Tributes – tribute messages with donations.

Categories – memorial organization and counts.

Memorial Owners – owner mapping per memorial.

Memorial Permissions – collaborative access rights.

Moderation Queue – tracks approval/rejection process.

🔎 Read-Only Functions

get-memorial → fetch memorial details (with privacy checks).

get-memorial-owner → current owner.

get-total-memorials → count of memorials.

get-tribute → fetch tribute details.

get-memorial-version → retrieve a past version.

get-category → fetch category info.

get-memorial-permissions → view collaborator rights.

get-moderation-status → status of pending memorials.

get-contract-stats → general stats (fees, approvals, totals).

is-memorial-owner → check ownership.

(Stubs) Search by creator, category, or tags.

🚀 Deployment & Usage

Deploy the contract on the Stacks blockchain.

Configure creation fee and approval requirements.

Create categories and start adding memorials.

Assign admins for moderation.

Allow tributes, donations, and collaborative edits.

📌 Notes & Extensions

Future improvements: full-text search by tags/categories, NFT transfer standard compliance, and DAO-style moderation.

Data-heavy fields (e.g., images) should be stored off-chain (IPFS/Arweave), with URIs referenced on-chain.