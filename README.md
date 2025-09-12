# 🏠 Rental NFTs for Real Estate

A revolutionary PropTech solution that tokenizes rental agreements using time-bound NFTs on the Stacks blockchain. Transform traditional rental processes with automated deposits, smart contract enforcement, and tamper-proof rental terms.

## 🌟 Features

- 🎫 **Time-bound NFTs** representing rental rights to physical properties
- 💰 **Automated deposits** and rent collection via smart contracts
- ⏰ **Rental period enforcement** with automatic expiration
- 🔄 **Property reusability** after rental completion
- 📊 **Earnings tracking** for landlords
- 🚪 **Check-in/Check-out** system for access management
- ⚡ **Emergency eviction** capabilities for landlords
- 📈 **Rental extension** functionality

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- [Stacks wallet](https://wallet.hiro.so/) for testnet

### Installation

```bash
git clone <repository-url>
cd Rental-NFTs-for-Real-Estate
clarinet check
```

### Running Tests

```bash
npm install
npm test
```

## 📖 Contract Usage

### 🏗️ For Landlords

#### 1. List Your Property
```clarity
(contract-call? .rental-nfts-for-real-estate list-property
  u100        ;; rent per block (STX)
  u5000       ;; deposit amount (STX)
  u1440       ;; max duration (blocks ~1 day)
  "123 Main St, City, State"  ;; property address
  "Beautiful 2BR apartment with amazing view"  ;; description
)
```

#### 2. Withdraw Earnings
```clarity
(contract-call? .rental-nfts-for-real-estate withdraw-earnings u1)
```

#### 3. Emergency Eviction (if needed)
```clarity
(contract-call? .rental-nfts-for-real-estate emergency-eviction u1)
```

### 🏠 For Tenants

#### 1. Rent a Property
```clarity
(contract-call? .rental-nfts-for-real-estate rent-property
  u1          ;; property ID
  u720        ;; duration in blocks (~12 hours)
)
```

#### 2. Check In
```clarity
(contract-call? .rental-nfts-for-real-estate check-in u1)
```

#### 3. Check Out (returns deposit)
```clarity
(contract-call? .rental-nfts-for-real-estate check-out u1)
```

#### 4. Extend Rental
```clarity
(contract-call? .rental-nfts-for-real-estate extend-rental u1 u360)  ;; extend by 6 hours
```

## 🔍 Read-Only Functions

### Get Property Information
```clarity
(contract-call? .rental-nfts-for-real-estate get-property-listing u1)
```

### Check Active Rental
```clarity
(contract-call? .rental-nfts-for-real-estate get-active-rental u1)
```

### Calculate Total Cost
```clarity
(contract-call? .rental-nfts-for-real-estate calculate-total-cost u1 u720)
```

### Check Remaining Time
```clarity
(contract-call? .rental-nfts-for-real-estate get-rental-time-remaining u1)
```

## 📊 Data Structures

### Property Listing
```clarity
{
  landlord: principal,
  rent-per-block: uint,
  deposit-amount: uint,
  max-duration: uint,
  available: bool,
  property-address: (string-ascii 256),
  description: (string-ascii 512)
}
```

### Active Rental
```clarity
{
  tenant: principal,
  start-block: uint,
  end-block: uint,
  deposit-paid: uint,
  rent-paid: uint,
  checked-in: bool,
  deposit-returned: bool
}
```

## 💡 Key Benefits

- 🛡️ **Fraud Prevention**: Immutable rental agreements on blockchain
- ⚖️ **Dispute Resolution**: Transparent, automated enforcement
- 🤝 **Trustless System**: No need for intermediaries
- 📱 **Modern UX**: Seamless digital rental experience
- 🌍 **Global Access**: Enables international short-term rentals
- ⚡ **Instant Settlement**: Automated payments and deposits

## 🔧 Technical Details

- **Blockchain**: Stacks (Bitcoin-secured)
- **Language**: Clarity smart contracts
- **NFT Standard**: SIP-009 compliant
- **Platform Fee**: 2.5% (adjustable by contract owner)

## 🚨 Important Notes

- NFTs automatically expire at rental end
- Deposits are returned upon successful check-out
- Emergency eviction available for landlords
- Platform fees are deducted from rent payments
- All payments are in STX (Stacks tokens)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue in this repository
- Join our community discussions
- Check the documentation

---

**⚠️ Disclaimer**: This is experimental software. Use at your own risk. Always test thoroughly on testnet before mainnet deployment.
