# RentChain - Digital Rent Ledger

## Overview

RentChain is a blockchain-based digital rent ledger that creates immutable landlord-tenant agreements and rental transaction records. Built on the Stacks network, it provides transparency, security, and trust in rental relationships through smart contract automation.

## Project Description

RentChain revolutionizes property rental management by creating:

- **Immutable Rental Agreements**: Tamper-proof lease contracts stored on-chain
- **Automated Rent Collection**: Smart contract-based rent payment processing
- **Transparent Rental History**: Complete transaction history for all parties
- **Dispute Resolution**: Clear record-keeping for legal and mediation purposes
- **Property Management**: Comprehensive property and tenant management system

## Smart Contracts

### 1. Rental Agreement Contract
- Manages property listings and lease agreement creation
- Handles tenant applications and landlord approvals
- Stores lease terms, rent amounts, and payment schedules
- Tracks property details and rental history
- Manages security deposits and property conditions

### 2. Payment Ledger Contract
- Processes monthly rent payments in STX
- Maintains payment history and late payment tracking
- Handles security deposit management
- Manages automatic payment reminders and penalties
- Provides real-time payment status updates

## Key Features

### For Landlords
- **Property Registration**: Register properties with complete details
- **Tenant Screening**: Review and approve tenant applications
- **Automated Rent Collection**: Receive payments automatically via smart contracts
- **Payment Tracking**: Monitor all rental payments in real-time
- **Legal Documentation**: Immutable lease agreements for legal protection

### For Tenants
- **Transparent Agreements**: Clear, immutable lease terms
- **Payment History**: Complete record of all rental payments
- **Dispute Protection**: Blockchain evidence for any disputes
- **Security Deposit Tracking**: Transparent handling of deposits
- **Payment Convenience**: Easy STX-based rent payments

### For Property Managers
- **Portfolio Management**: Manage multiple properties and tenants
- **Financial Reporting**: Comprehensive rental income tracking
- **Maintenance Records**: Track property maintenance and repairs
- **Compliance Monitoring**: Ensure regulatory compliance
- **Risk Assessment**: Historical data for tenant evaluation

## Technology Stack

- **Blockchain**: Stacks Network
- **Smart Contracts**: Clarity Language
- **Testing Framework**: Clarinet
- **Development Environment**: Clarinet CLI

## Benefits

### Trust and Transparency
- All agreements and payments recorded on blockchain
- No possibility of tampering with rental records
- Complete transaction history accessible to all parties
- Reduced disputes through clear documentation

### Efficiency
- Automated rent collection reduces administrative overhead
- Smart contract enforcement eliminates manual processes
- Real-time payment status updates
- Streamlined tenant application and approval process

### Legal Protection
- Immutable lease agreements serve as legal documents
- Complete payment history for court proceedings
- Time-stamped records for regulatory compliance
- Audit trail for tax and accounting purposes

### Financial Benefits
- Reduced late payments through automated reminders
- Lower administrative costs
- Improved cash flow through timely payments
- Transparent fee structure

## System Architecture

### Rental Agreement Flow
1. Landlord registers property with rental terms
2. Tenant submits application with required information
3. Landlord reviews and approves/rejects application
4. Smart contract creates immutable lease agreement
5. Security deposit and first month's rent processed

### Payment Processing Flow
1. Monthly rent payment automatically triggered
2. Smart contract validates payment amount and timing
3. Payment processed from tenant to landlord
4. Payment recorded in immutable ledger
5. Late fees applied if payment overdue

## Security Features

- **Access Control**: Role-based permissions for landlords, tenants, and managers
- **Data Validation**: Input validation and sanitization
- **Fraud Prevention**: Immutable records prevent document tampering
- **Privacy Protection**: Personal information encrypted and securely stored

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm
- Git
- Stacks wallet for STX transactions

### Installation
```bash
git clone <repository-url>
cd RentChain
npm install
clarinet check
npm test
```

## Usage

### For Landlords
1. Register your property with rental details
2. Set rental terms and lease conditions
3. Review and approve tenant applications
4. Receive automated rent payments
5. Access complete rental history

### For Tenants
1. Browse available properties
2. Submit rental applications
3. Sign digital lease agreements
4. Make monthly rent payments via STX
5. Access payment history and lease details

## Smart Contract Functions

### Property Management
- `register-property`: Add new rental property
- `update-property`: Modify property details
- `set-rental-terms`: Define lease conditions
- `approve-tenant`: Accept rental application

### Payment Processing
- `make-rent-payment`: Process monthly rent
- `handle-late-payment`: Apply penalties
- `manage-security-deposit`: Handle deposit transactions
- `generate-payment-report`: Create financial reports

## Compliance and Legal

RentChain is designed to comply with:
- Local housing regulations
- Tenant rights legislation
- Financial transaction requirements
- Data protection laws

## Support

For technical support or questions about RentChain, please refer to our documentation or contact the development team.

## Contributing

We welcome contributions to improve RentChain. Please read our contributing guidelines before submitting pull requests.

## License

This project is licensed under the MIT License.
