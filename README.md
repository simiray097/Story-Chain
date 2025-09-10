# 📚 Story Chain

> A collaborative storytelling platform on the Stacks blockchain where users contribute sentences to create shared narratives

## 🌟 Overview

Story Chain is a decentralized application that enables collaborative storytelling on the blockchain. Users can create new stories and contribute sentences to existing ones, building narratives together in a transparent and immutable way.

## ✨ Features

- 📖 **Create Stories**: Start new collaborative stories with custom titles
- ✍️ **Add Sentences**: Contribute sentences to existing stories (5-280 characters)
- 👥 **User Statistics**: Track contributions, stories created, and participation
- 🔒 **Story Management**: Creators can activate/deactivate their stories
- 📊 **Story Discovery**: Browse latest stories and read complete narratives
- 🏆 **Contribution Tracking**: Monitor user participation across different stories

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation

```bash
git clone <your-repo>
cd story-chain
clarinet check
```

## 📋 Contract Functions

### Public Functions

#### `create-story`
Create a new collaborative story
```clarity
(contract-call? .story-chain create-story "Once upon a time")
```

#### `add-sentence`
Add a sentence to an existing story
```clarity
(contract-call? .story-chain add-sentence u1 "The brave knight ventured forth.")
```

#### `toggle-story-status`
Toggle story active/inactive status (creator only)
```clarity
(contract-call? .story-chain toggle-story-status u1)
```

### Read-Only Functions

#### `get-story`
Retrieve story information
```clarity
(contract-call? .story-chain get-story u1)
```

#### `get-sentence`
Get a specific sentence from a story
```clarity
(contract-call? .story-chain get-sentence u1 u1)
```

#### `get-story-sentences`
Get multiple sentences from a story with pagination
```clarity
(contract-call? .story-chain get-story-sentences u1 u0 u10)
```

#### `get-user-stats`
View user's contribution statistics
```clarity
(contract-call? .story-chain get-user-stats 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### `get-latest-stories`
Browse recent stories
```clarity
(contract-call? .story-chain get-latest-stories u5)
```

## 🎮 Usage Examples

### Creating Your First Story

```bash
clarinet console
```

```clarity
(contract-call? .story-chain create-story "The Mystery of the Lost Code")
```

### Adding to the Story

```clarity
(contract-call? .story-chain add-sentence u1 "In a small town, a programmer discovered something unusual in their code.")
(contract-call? .story-chain add-sentence u1 "The variables seemed to be changing themselves at midnight.")
```

### Reading the Story

```clarity
(contract-call? .story-chain get-story-sentences u1 u0 u10)
```

## 🔧 Development

### Testing

```bash
clarinet test
```

### Deployment

```bash
clarinet deploy --testnet
```

## 📊 Data Structure

### Stories
- **story-id**: Unique identifier
- **title**: Story title (max 100 chars)
- **creator**: Story creator's principal
- **sentence-count**: Number of sentences
- **created-at**: Block height when created
- **is-active**: Whether accepting new sentences

### Sentences
- **content**: Sentence text (5-280 chars)
- **author**: Sentence author's principal
- **added-at**: Block height when added

### User Stats
- **total-sentences**: Total sentences contributed
- **stories-created**: Number of stories created
- **stories-contributed**: Number of different stories contributed to

## 🛡️ Security Features

- ✅ Input validation for sentence length
- ✅ Creator-only story management
- ✅ Active story enforcement
- ✅ Principal-based authentication
- ✅ Overflow protection

## 🎯 Use Cases

- 📚 **Educational**: Learn collaborative blockchain development
- 🎨 **Creative Writing**: Community storytelling projects  
- 🏢 **Team Building**: Corporate collaborative exercises
- 🎮 **Gaming**: Story-driven blockchain games
- 📖 **Literature**: Decentralized publishing experiments

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test your changes with `clarinet test`
4. Submit a pull request

## 📄 License

MIT License - feel free to use this project for learning and building!

---

*Built with ❤️ for the Stacks ecosystem*
```

**Git Commit Message:**
```
feat: implement collaborative story chain smart contract with sentence contributions and user stats
```

**GitHub Pull Request Title:**
```
🚀 Add Story Chain MVP - Collaborative Storytelling Smart Contract
```

**GitHub Pull Request Description:**
```
## 📚 Story Chain MVP Implementation

This PR introduces a complete MVP for a collaborative storytelling platform on Stacks blockchain.

### ✨ Features Added
- **Story Creation**: Users can create new collaborative stories with titles
- **Sentence Contributions**: Add sentences (5-280 chars) to existing stories  
- **User Statistics**: Track contributions, stories created, and participation
- **Story Management**: Creators can toggle story active/inactive status
- **Data Retrieval**: Read stories, sentences, and user stats with pagination
- **Input Validation**: Comprehensive error handling and security checks

### 🔧 Technical Implementation
- 150+ lines of clean Clarity code
- Efficient data structures using maps for stories, sentences, and user data
- Read-only functions for data access with pagination support
- Public functions for story creation and sentence addition
- Private helper functions for user statistics management

### 📊 Contract Structure
- **Stories Map**: Store story metadata and status
- **Sentences Map**: Store individual sentence contributions
- **User Stats**: Track user participation across the platform
- **Contribution Tracking**: Monitor user activity per story

### 🛡️ Security & Validation
- Sentence length validation (5-280 characters)
- Creator-only story management permissions
- Active story enforcement for new contributions
- Input sanitization and error handling

### 📖 Documentation
- Complete README with usage examples
- Function documentation and parameter descriptions
- Development setup and testing instructions
- Real-world use case examples

Ready for testing and deployment! 🎉
