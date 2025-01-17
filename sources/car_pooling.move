module car_pooling::car_pooling {
    // This module defines the car pooling system.

    // Importing necessary modules from the standard library and SUI.
    use sui::sui::SUI;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};

    // Structs definition for the car pooling system

    // Struct to store information about the car pooling service.
    public struct ServiceCap has key, store {
        id: UID,
        trips: vector<ID>, // Vector to store the IDs of trips managed by the service.
        wallet: Balance<SUI>, // Balance representing the total funds collected by the service.
        management: address, // Address of the service management.
        service_fee: u64, // Service fee charged by the car pooling service.
    }

    // Struct to represent a trip.
    public struct Trip has key, store {
        id: UID,
        passengers: vector<address>, // Vector to store the addresses of passengers in the trip.
        driver: address, // Address of the driver of the trip.
        destination: String, // Destination of the trip.
        fare: u64, // Fare for the trip.
        completed: bool, // Status indicating if the trip is completed.
        pool: Balance<SUI>, // Balance representing the total funds collected in the trip pool.
    }

    // Struct to represent a passenger in a trip.
    public struct Passenger has key, store {
        id: UID,
        passenger: address, // Address of the passenger.
        balance: Balance<SUI>, // Balance representing the funds deposited by the passenger.
    }

    // Error codes used in the car pooling system.
    const ENotOwner: u64 = 1;
    const ENotPassenger: u64 = 2;
    const EInsufficientBalance: u64 = 5;
    const ETripCompleted: u64 = 6;

    // Functions for managing the car pooling system.
    fun init(ctx: &mut TxContext) {
        let service = ServiceCap {
            id: object::new(ctx),
            trips: vector::empty<ID>(),
            wallet: balance::zero<SUI>(),
            management: tx_context::sender(ctx),
            service_fee: 0,
        };
        transfer::transfer(service, tx_context::sender(ctx));
    }

    // set service fee
    public fun set_service_fee(
        service: &mut ServiceCap,
        fee: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == service.management, ENotOwner); // Add access control check
        service.service_fee = fee;
    }

    // Adds a new passenger to the system.
    public fun add_passenger(
        passenger: address,
        ctx: &mut TxContext
    ) : Passenger {
        let id = object::new(ctx);
        Passenger {
            id,
            passenger,
            balance: balance::zero<SUI>(),
        }
    }

    // Deposits funds into a passenger's balance.
    public fun deposit(
        passenger: &mut Passenger,
        amount: Coin<SUI>,
    ) {
        let coin = coin::into_balance(amount);
        balance::join(&mut passenger.balance, coin);
    }

    // Creates a new trip.
    public fun create_trip(
        service: &mut ServiceCap,
        driver: address,
        destination: String,
        fare: u64,
        ctx: &mut TxContext
    ) {
        let id = object::new(ctx);
        let inner = object::uid_to_inner(&id);
        let trip = Trip {
            id,
            passengers: vector::empty(),
            driver,
            destination,
            fare,
            completed: false,
            pool: balance::zero<SUI>(),
        };
        transfer::share_object(trip);
        vector::push_back(&mut service.trips, inner);
    }

    // Allows a passenger to view trips
    public fun view_trips(
        service: &ServiceCap,
    ) : vector<ID> {
        service.trips
    }

    // Allows a passenger to join a trip.
    public fun join_trip(
        trip: &mut Trip,
        passenger: &mut Passenger,
        ctx: &mut TxContext
    ) {
        assert!(balance::value(&passenger.balance) >= trip.fare, EInsufficientBalance);
        
        let fare = coin::take(&mut passenger.balance, trip.fare, ctx);
        coin::put(&mut trip.pool, fare);

        vector::push_back(&mut trip.passengers, passenger.passenger);
    }

    // Completes a trip.
    public fun complete_trip(
        trip: &mut Trip,
        ctx: &mut TxContext
    ) {
        assert!(!trip.completed, ETripCompleted);
        
        let payment = balance::withdraw_all(&mut trip.pool);
        let coin = coin::from_balance(payment, ctx);
        transfer::public_transfer(coin, trip.driver);

        trip.completed = true;
    }

    // Withdraws funds from a passenger's balance.
    public fun withdraw(
        passenger: &mut Passenger,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == passenger.passenger, ENotPassenger); // Add access control check
        assert!(balance::value(&passenger.balance) >= amount, EInsufficientBalance);
        let withdrawn = coin::take(&mut passenger.balance, amount, ctx);
        transfer::public_transfer(withdrawn, passenger.passenger);
    }

    // Withdraws funds from the service's wallet.
    public fun withdraw_wallet(
        service: &mut ServiceCap,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == service.management, ENotOwner); // Add access control check
        assert!(balance::value(&service.wallet) >= amount, EInsufficientBalance);
        let withdrawn = coin::take(&mut service.wallet, amount, ctx);
        transfer::public_transfer(withdrawn, service.management);
    }
}
