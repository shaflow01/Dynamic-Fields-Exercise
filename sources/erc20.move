module erc20::erc20{
    use std::string;
    use std::ascii;
    use std::type_name;
    use sui::object::{Self, UID};
    use sui::bag::{Self, Bag};
    use sui::table::{Self, Table};
    use sui::tx_context::{Self,TxContext};
    use sui::transfer;
    use sui::event;

    const AddressZero: address = @0x0;

    const EBadWitnessErr: u64 = 0;
    const AlreadlyInitlizeErr: u64 = 1;
    const BadTypeOrNotInitlizeErr: u64 = 2;
    const OverFlowErr: u64 = 3;
    const NotEnoughBalanceErr: u64 = 4;
    const AddressZeroErr: u64 = 5;
    const NotEnoughAllowanceErr: u64 = 6;

    struct Transfer has copy, drop {
        from: address,
        to: address,
        value: u64,
    }

    struct Approve has copy, drop {
        owner: address,
        spender: address,
        value: u64,
    }

    struct BalanceData<phantom T> has key, store{
        id: UID,
        balance:Table<address,u64>,
        totalsupply: u64,
    }

    struct BalanceList has key,store{
        id: UID,
        balance_list: Bag,
    }

    struct AllowanceData<phantom T> has key, store{
        id: UID,
        allowance:Table<address , AllowanceAmountList>,
    }

    struct AllowanceAmountList has key, store{
        id: UID,
        allowance_amount: Table<address, u64>,
    }

    struct AllowanceList has key,store{
        id: UID,
        allowance_list: Bag,
    }

    struct ERC20MetaData<phantom T> has key, store{
        id: UID,
        name: string::String,
        symbol: ascii::String,
        decimal: u8,
    }

    struct TreasuryCap<phantom T> has key,store{
        id:UID,
    }

    struct TokenCap<phantom T> has key{
        id: UID,
    }

    fun init(ctx:&mut TxContext){

        let balance_list =  BalanceList{
            id: object::new(ctx),
            balance_list: bag::new(ctx),
        };

        let allowance_list = AllowanceList{
            id: object::new(ctx),
            allowance_list: bag::new(ctx),
        };

        transfer::share_object(balance_list);
        transfer::share_object(allowance_list);
        
    }

    public fun create_token<T: drop>(witness: T, name: vector<u8>, symbol: vector<u8>, decimal:u8, ctx:&mut TxContext):TreasuryCap<T>{

        assert!(sui::types::is_one_time_witness(&witness), EBadWitnessErr);

        let erc20_metadata = ERC20MetaData<T>{
            id: object::new(ctx),
            name: string::utf8(name),
            symbol: ascii::string(symbol),
            decimal: decimal,
        };

        let treasury_cap = TreasuryCap<T>{
            id: object::new(ctx),
        };

        let token_cap = TokenCap<T>{
            id: object::new(ctx),
        };

        transfer::share_object(erc20_metadata);
        transfer::share_object(token_cap);
        treasury_cap
    }

    public fun init_token<T>(_:&TokenCap<T>,balance_list: &mut BalanceList, allowance_list: &mut AllowanceList,ctx:&mut TxContext){
        let type = ascii::into_bytes(type_name::into_string(type_name::get_with_original_ids<T>()));
        assert!(!bag::contains(& balance_list.balance_list, type), AlreadlyInitlizeErr);
        assert!(!bag::contains(& allowance_list.allowance_list, type), AlreadlyInitlizeErr);
        let balance_data = BalanceData<T>{
            id: object::new(ctx),
            balance: table::new(ctx),
            totalsupply: 0,
        };

        bag::add(&mut balance_list.balance_list, type, balance_data);
        let allowance_data = AllowanceData<T>{
            id: object::new(ctx),
            allowance: table::new(ctx),
        };

        bag::add(&mut allowance_list.allowance_list, type, allowance_data);
    }


    public fun mint<T>(_: &TreasuryCap<T> ,balance_list: &mut BalanceList, to:address, value: u64, ctx:&mut TxContext): bool{
        if(value == 0){
            return true
        };
        let type = ascii::into_bytes(type_name::into_string(type_name::get_with_original_ids<T>()));
        assert!(bag::contains(&balance_list.balance_list, type), BadTypeOrNotInitlizeErr);
        let balance_table = bag::borrow_mut< vector<u8>, BalanceData<T> >(&mut balance_list.balance_list, type);

        event::emit(
            Transfer {
                from: AddressZero,
                to: to,
                value: value,
            }
        );

        if(table::contains(&balance_table.balance, to)){
            let balance_to = table::borrow_mut(&mut balance_table.balance,to);
            assert!(*balance_to + value >= *balance_to, OverFlowErr);
            *balance_to = *balance_to + value;
        }else{
            table::add(&mut balance_table.balance, to, value);
        };
        let totalsupply = &mut balance_table.totalsupply;
        assert!(*totalsupply + value >= *totalsupply, OverFlowErr);
        *totalsupply = *totalsupply + value;
        return true
    }

    public fun burn<T>(_: &TreasuryCap<T>, balance_list: &mut BalanceList, from:address, value: u64, ctx:&mut TxContext): bool{
        if(value == 0){
            return true
        };
        let type = ascii::into_bytes(type_name::into_string(type_name::get_with_original_ids<T>()));
        assert!(bag::contains(&balance_list.balance_list, type), BadTypeOrNotInitlizeErr);
        let balance_table = bag::borrow_mut<vector<u8>, BalanceData<T>>(&mut balance_list.balance_list, type);

        if(table::contains(&balance_table.balance, from)){
            let balance_to = table::borrow_mut(&mut balance_table.balance,from);
            assert!(*balance_to >= value, NotEnoughBalanceErr);
            event::emit(
                Transfer {
                    from: from,
                    to: AddressZero,
                    value: value,
                }
            );
            if(*balance_to > value){
                *balance_to = *balance_to - value;
            }
            else{
                table::remove(&mut balance_table.balance,from);
            };
            let totalsupply = &mut balance_table.totalsupply;
            *totalsupply = *totalsupply - value;
        }else{
            assert!(false, NotEnoughBalanceErr)
        };
        return true
    }



    public fun transfer<T>(_:& TokenCap<T>, balance_list: &mut BalanceList, to:address, value: u64, ctx:&mut TxContext):bool{
        assert!(to != AddressZero, AddressZeroErr);
        if(value == 0){
            return true
        };
        let type = ascii::into_bytes(type_name::into_string(type_name::get_with_original_ids<T>()));
        assert!(bag::contains(&balance_list.balance_list, type), BadTypeOrNotInitlizeErr);
        transfer_in(bag::borrow_mut<vector<u8>, BalanceData<T>>(&mut balance_list.balance_list, type), tx_context::sender(ctx), to, value);
        return true
    }

    public fun approve<T>(_:& TokenCap<T>, allowance_list: &mut AllowanceList,spender:address, value:u64, ctx:&mut TxContext):bool {
        if(value == 0){
            return true
        };
        let type = ascii::into_bytes(type_name::into_string(type_name::get_with_original_ids<T>()));
        assert!(spender != AddressZero, AddressZeroErr);
        assert!(bag::contains(&allowance_list.allowance_list, type), BadTypeOrNotInitlizeErr);
        //get AllowanceData
        let allowance_table = bag::borrow_mut<vector<u8>, AllowanceData<T>>(&mut allowance_list.allowance_list, type);

        event::emit(
            Approve {
                owner: tx_context::sender(ctx),
                spender: spender,
                value: value,
            }
        );
        //if have AllowanceAmountList
        if(table::contains(&allowance_table.allowance, tx_context::sender(ctx))){
            let allowance = table::borrow_mut(&mut allowance_table.allowance, tx_context::sender(ctx));

            //if have allowance_amount
            if(table::contains(&allowance.allowance_amount,spender)){
                let amount = table::borrow_mut(&mut allowance.allowance_amount,spender);
                *amount = value;
            }
            else{
                table::add(&mut allowance.allowance_amount, spender, value);
            }
        }else{
            //add AllowanceAmountList
            let allowance_amount = table::new(ctx);
            table::add(&mut allowance_amount, spender, value);
            let allowance_list = AllowanceAmountList{
                id: object::new(ctx),
                allowance_amount: allowance_amount,
            };
            table::add(&mut allowance_table.allowance,tx_context::sender(ctx),allowance_list);
        };
        return true
    }

    public fun transferFrom<T>(_:& TokenCap<T>, allowance_list: &mut AllowanceList,balance_list: &mut BalanceList,from: address, to: address, value: u64, ctx:&mut TxContext):bool{
        assert!(from != AddressZero, AddressZeroErr);
        assert!(to != AddressZero, AddressZeroErr);
        if(value == 0){
            return true
        };
        let type = ascii::into_bytes(type_name::into_string(type_name::get_with_original_ids<T>()));
        assert!(bag::contains(&allowance_list.allowance_list, type), BadTypeOrNotInitlizeErr);
        assert!(bag::contains(&balance_list.balance_list, type), BadTypeOrNotInitlizeErr);

        spender_allowance(bag::borrow_mut<vector<u8>, AllowanceData<T>>(&mut allowance_list.allowance_list, type), from, tx_context::sender(ctx), value);

        transfer_in(bag::borrow_mut<vector<u8>, BalanceData<T>>(&mut balance_list.balance_list, type), from ,to,value);
        return true
    }
    
    public fun balance_of<T>(_token_cap :& TokenCap<T>, balance_list: &mut BalanceList, addr:address, ctx:&mut TxContext):u64{
        let type = ascii::into_bytes(type_name::into_string(type_name::get_with_original_ids<T>()));
        assert!(bag::contains(&balance_list.balance_list, type), BadTypeOrNotInitlizeErr);
        let balance_table = bag::borrow<vector<u8>, BalanceData<T>>(& balance_list.balance_list, type);
        if(table::contains(&balance_table.balance, addr)){
            let amount = *(table::borrow(& balance_table.balance,addr));
            return amount
        };
        return 0
    }

    public fun total_supply<T>(_token_cap :& TokenCap<T>, balance_list: &mut BalanceList, ctx:&mut TxContext): u64{
        let type = ascii::into_bytes(type_name::into_string(type_name::get_with_original_ids<T>()));
        assert!(bag::contains(&balance_list.balance_list, type), BadTypeOrNotInitlizeErr);
        let balance_table = bag::borrow<vector<u8>, BalanceData<T>>(& balance_list.balance_list, type);
        return balance_table.totalsupply
    }

    public fun get_allowance<T>(_token_cap :& TokenCap<T>,allowance_list: &mut AllowanceList, owner:address, spender:address,ctx:&mut TxContext):u64{
        let type = ascii::into_bytes(type_name::into_string(type_name::get_with_original_ids<T>()));
        assert!(bag::contains(&allowance_list.allowance_list, type), BadTypeOrNotInitlizeErr);

        let allowance_data_list = bag::borrow<vector<u8>, AllowanceData<T>>(& allowance_list.allowance_list, type);

        if(table::contains(&allowance_data_list.allowance, owner)){
            let allowance = table::borrow<address, AllowanceAmountList>(& allowance_data_list.allowance, owner);
            if(table::contains(&allowance.allowance_amount,spender)){
                let allowance_amount = *(table::borrow<address, u64>(& allowance.allowance_amount,spender));
                return allowance_amount
            }
        };
        return 0
    }
    
    fun transfer_in<T>(balance_table:&mut BalanceData<T>, from: address, to:address, value: u64){
        assert!(table::contains(&balance_table.balance,from), NotEnoughBalanceErr);

        let balance_from = table::borrow_mut(&mut balance_table.balance, from);
        assert!(*balance_from >= value , NotEnoughBalanceErr);
        if(*balance_from > value){
            *balance_from = *balance_from - value;
        }
        else{
            table::remove(&mut balance_table.balance ,from);
        };
        event::emit(
            Transfer {
                from: from,
                to: to,
                value: value,
            }
        );
        if(table::contains(&balance_table.balance, to)){
            let balance_to = table::borrow_mut(&mut balance_table.balance,to);
            assert!(*balance_to + value >= *balance_to, OverFlowErr);
            *balance_to = *balance_to + value;
        }else{
            table::add(&mut balance_table.balance, to, value);
        };

    }

    fun spender_allowance<T>(allowance_table:&mut AllowanceData<T>, from:address ,spender: address, value: u64){
        assert!(table::contains(&allowance_table.allowance, from), NotEnoughAllowanceErr);
        let allowance = table::borrow_mut(&mut allowance_table.allowance, from);
        
        assert!(table::contains(&allowance.allowance_amount, spender),NotEnoughAllowanceErr);
        let amount = table::borrow_mut(&mut allowance.allowance_amount, spender);

        assert!(*amount >= value, 7);
        let new_amount = *amount - value;
        event::emit(
            Approve {
                owner: from,
                spender: spender,
                value: new_amount,
            }
        );
        if(new_amount > 0){
            *amount = new_amount;
        }
        else{
            *amount = new_amount;
            table::remove(&mut allowance.allowance_amount, spender);
        };
    }

    #[test_only]
    public fun test_init(ctx:&mut TxContext){
        init(ctx);
    }
}