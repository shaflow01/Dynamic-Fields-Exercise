
#[test_only]
module erc20::erc20test{
    use erc20::erc20::{Self,TokenCap,BalanceList,TreasuryCap,AllowanceList};
    use sui::test_scenario::{Self, Scenario};
    use sui::tx_context::{Self,TxContext};
    use sui::transfer;

    struct ERC20TEST has drop{}
    fun init(witness: ERC20TEST, ctx: &mut TxContext){
        let treasury_cap = erc20::create_token(witness,b"ETC20Test", b"ERCT", 18, ctx);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }
    #[test_only]
    fun test_mint(scenario: &mut Scenario, sender: address, to: address, amount:u64) {
        test_scenario::next_tx(scenario, sender);
        let treasury_cap: TreasuryCap<ERC20TEST> = test_scenario::take_from_sender(scenario);
        let balance_list = test_scenario::take_shared<BalanceList>(scenario);
        erc20::mint(&treasury_cap, &mut balance_list, to, amount, test_scenario::ctx(scenario));
        test_scenario::return_shared(balance_list);
        test_scenario::return_to_sender(scenario, treasury_cap);
    }

    

    #[test_only]
    fun test_burn(scenario: &mut Scenario, sender: address, to: address, amount:u64){
        test_scenario::next_tx(scenario, sender);
        let treasury_cap: TreasuryCap<ERC20TEST> = test_scenario::take_from_sender(scenario);
        let balance_list = test_scenario::take_shared<BalanceList>(scenario);
        erc20::burn(&treasury_cap, &mut balance_list, to, amount, test_scenario::ctx(scenario));
        test_scenario::return_shared(balance_list);
        test_scenario::return_to_sender(scenario, treasury_cap);
    }

    #[test_only]
    fun test_transfer(scenario: &mut Scenario, from:address, to: address, amount:u64){
        test_scenario::next_tx(scenario, from);
        let token_cap: TokenCap<ERC20TEST> = test_scenario::take_shared(scenario);
        let balance_list:BalanceList = test_scenario::take_shared(scenario);
        erc20::transfer(&token_cap,&mut balance_list, to, amount, test_scenario::ctx(scenario));
        test_scenario::return_shared(balance_list);
        test_scenario::return_shared(token_cap);
    }

    #[test_only]
    fun test_approve(scenario: &mut Scenario, owner:address, spender: address,amount:u64){
        test_scenario::next_tx(scenario, owner);
        let token_cap: TokenCap<ERC20TEST> = test_scenario::take_shared(scenario);
        let allowance_list = test_scenario::take_shared<AllowanceList>(scenario);
        erc20::approve(&token_cap,&mut allowance_list,spender,amount,test_scenario::ctx(scenario));
        test_scenario::return_shared(allowance_list);
        test_scenario::return_shared(token_cap);
    }

    #[test_only]
    fun test_transfer_from(scenario: &mut Scenario,owner:address, spender:address,amount:u64){
        test_scenario::next_tx(scenario, spender);
        let token_cap: TokenCap<ERC20TEST> = test_scenario::take_shared(scenario);
        let allowance_list = test_scenario::take_shared<AllowanceList>(scenario);
        let balance_list = test_scenario::take_shared<BalanceList>(scenario);
        erc20::transferFrom(&token_cap,&mut allowance_list,&mut balance_list,owner,spender,amount,test_scenario::ctx(scenario));
        test_scenario::return_shared(allowance_list);
        test_scenario::return_shared(token_cap);
        test_scenario::return_shared(balance_list);
    }

    #[test_only]
    fun get_balance(scenario: &mut Scenario, sender: address, to:address): u64{
        test_scenario::next_tx(scenario, sender);
        let token_cap: TokenCap<ERC20TEST> = test_scenario::take_shared(scenario);
        let balance_list = test_scenario::take_shared<BalanceList>(scenario);
        let balance = erc20::balance_of(&token_cap,&mut balance_list, to,test_scenario::ctx(scenario));
        test_scenario::return_shared(balance_list);
        test_scenario::return_shared(token_cap);
        return balance
    }

    #[test_only]
    fun get_totalsupply(scenario: &mut Scenario, sender: address): u64{
        test_scenario::next_tx(scenario, sender);
        let token_cap: TokenCap<ERC20TEST> = test_scenario::take_shared(scenario);
        let balance_list = test_scenario::take_shared<BalanceList>(scenario);
        let total_supply = erc20::total_supply(&token_cap,&mut balance_list,test_scenario::ctx(scenario));
        test_scenario::return_shared(balance_list);
        test_scenario::return_shared(token_cap);
        return total_supply
    }

    #[test_only]
    fun get_allowance(scenario: &mut Scenario,owner: address, spender: address): u64{
        test_scenario::next_tx(scenario, spender);
        let allowance_list = test_scenario::take_shared<AllowanceList>(scenario);
        let token_cap: TokenCap<ERC20TEST> = test_scenario::take_shared(scenario);
        let allowance_amount = erc20::get_allowance(&token_cap, &mut allowance_list, owner, spender,test_scenario::ctx(scenario));
        test_scenario::return_shared(allowance_list);
        test_scenario::return_shared(token_cap);
        return allowance_amount
    }

    #[test]
    public fun test(){
        let addr1 = @0xA;
        let addr2 = @0xB;

        let scenario = test_scenario::begin(addr1);
        //1. create a token
        {
            erc20::test_init(test_scenario::ctx(&mut scenario));
            test_scenario::next_tx(&mut scenario, addr1);
            init(ERC20TEST{}, test_scenario::ctx(&mut scenario));
            test_scenario::next_tx(&mut scenario, addr1);
            let balance_list = test_scenario::take_shared<BalanceList>(&mut scenario);
            let allowance_list= test_scenario::take_shared(&mut scenario);
            let token_cap: TokenCap<ERC20TEST> = test_scenario::take_shared(&mut scenario);
            erc20::init_token(&token_cap,&mut balance_list,&mut allowance_list, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(balance_list);
            test_scenario::return_shared(allowance_list);
            test_scenario::return_shared(token_cap);
        };

        //2. mint
        {

            assert!(get_balance(&mut scenario,addr1,  addr1) == 0, 0);
            assert!(get_totalsupply(&mut scenario, addr1) == 0, 0);

            test_mint(&mut scenario, addr1, addr1, 1000);

            assert!(get_balance(&mut scenario,addr1,  addr1) == 1000, 0);
            assert!(get_totalsupply(&mut scenario,addr1) == 1000, 0);

            test_mint(&mut scenario, addr1, addr1, 1000);

            assert!(get_balance(&mut scenario,addr1,  addr1) == 2000, 0);
            assert!(get_totalsupply(&mut scenario,addr1) == 2000, 0);

        };

        //3. burn 
        {

            test_burn(&mut scenario, addr1, addr1, 1000);

            assert!(get_balance(&mut scenario,addr1, addr1) == 1000, 0);
            assert!(get_totalsupply(&mut scenario,addr1) == 1000, 0);

            test_burn(&mut scenario, addr1, addr1, 1000);

            assert!(get_balance(&mut scenario,addr1,  addr1) == 0, 0);
            assert!(get_totalsupply(&mut scenario,addr1) == 0, 0);

        };

        //3.transfer
        {   
            test_scenario::next_tx(&mut scenario, addr1);
            test_mint(&mut scenario, addr1, addr1, 1000);

            assert!(get_balance(&mut scenario,addr1,  addr1) == 1000, 0);
            assert!(get_balance(&mut scenario,addr2,  addr2) == 0, 0);

            test_transfer(&mut scenario, addr1, addr2, 500);

            assert!(get_balance(&mut scenario,addr1,  addr1) == 500, 0);
            assert!(get_balance(&mut scenario,addr2,  addr2) == 500, 0);

        };

        //4.transferFrom
        {

            assert!(get_allowance(&mut scenario, addr1, addr2) == 0,0);

            test_approve(&mut scenario, addr1, addr2, 500);

            assert!(get_allowance(&mut scenario, addr1, addr2 ) == 500,0);

            test_transfer_from(&mut scenario, addr1, addr2, 300);

            assert!(get_allowance(&mut scenario, addr1, addr2 ) == 200,0);
            assert!(get_balance(&mut scenario,addr2,  addr1) == 200, 0);
            assert!(get_balance(&mut scenario,addr2, addr2) == 800, 0);

        };

        test_scenario::end(scenario);
    }
}
