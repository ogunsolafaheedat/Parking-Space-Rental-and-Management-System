# Parking Space Rental and Management System

A comprehensive blockchain-based parking space rental system built with Clarity smart contracts on the Stacks blockchain.

## Overview

This system provides a decentralized platform for parking space rental and management, featuring:

- **Parking Space Management**: Register and manage parking spots with location data
- **Reservation System**: Book parking spaces with time-based availability
- **Payment Processing**: Handle payments and deposits securely
- **Access Control**: Manage entry/exit permissions and validation
- **Dispute Resolution**: Handle conflicts and damage reports transparently

## Architecture

The system consists of 5 main smart contracts:

1. **parking-spaces.clar** - Core parking space registration and management
2. **reservations.clar** - Booking and reservation handling
3. **payments.clar** - Payment processing and escrow management
4. **access-control.clar** - Entry/exit validation and permissions
5. **disputes.clar** - Dispute resolution and damage reporting

## Key Features

### For Parking Space Owners
- Register parking spaces with detailed location and pricing information
- Set availability schedules and pricing tiers
- Manage access permissions and monitor usage
- Handle disputes and damage claims

### For Renters
- Search and book available parking spaces
- Make secure payments with escrow protection
- Access parking spaces with digital validation
- Report issues and file disputes when necessary

### System Features
- Location-based search and filtering
- Real-time availability tracking
- Automated payment processing
- Transparent dispute resolution
- Monthly parking subscriptions
- Commuter coordination features

## Data Structures

### Parking Space
- Space ID (unique identifier)
- Owner principal
- Location coordinates and address
- Hourly/daily/monthly rates
- Availability schedule
- Space type and features
- Status (active/inactive/maintenance)

### Reservation
- Reservation ID
- Space ID and renter principal
- Start and end timestamps
- Payment amount and status
- Access code generation
- Cancellation policy

### Payment
- Payment ID and amount
- Payer and recipient principals
- Escrow status and release conditions
- Refund eligibility and processing

## Getting Started

1. Install Clarinet CLI
2. Clone this repository
3. Run `clarinet check` to validate contracts
4. Run `npm test` to execute the test suite
5. Deploy contracts using `clarinet deploy`

## Testing

The system includes comprehensive tests using Vitest:

\`\`\`bash
npm install
npm test
\`\`\`

## Contract Interactions

### Register a Parking Space
```clarity
(contract-call? .parking-spaces register-space 
  {lat: 40.7128, lng: -74.0060} 
  "123 Main St, NYC" 
  {hourly: u500, daily: u2000, monthly: u50000}
  "outdoor")
