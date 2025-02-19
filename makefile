include .env
export $(shell sed 's/=.*//' .env)

deploy_shitcoin_factory:
	@echo "Deploying DaosWorldShitcoinFactory to Base Mainnet"
	@forge script script/Deployer.s.sol:DaosWorldShitcoinFactoryScript --rpc-url $(BASE_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify -vvvvv --legacy
	@echo "Deployment completed!"

check_shitcoin_factory:
	@echo "Checking DaosWorldShitcoinFactory deployment"
	@forge script script/Deployer.s.sol:DaosWorldShitcoinFactoryScript --rpc-url $(BASE_RPC_URL) --private-key $(PRIVATE_KEY) -vvvv

deploy_factory_v2:
	@echo "Deploying DaosWorldFactoryV2 to Base Mainnet"
	@forge script script/Deployer.s.sol:DaosWorldFactoryV2Script --rpc-url $(BASE_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify -vvvvv --legacy
	@echo "Deployment completed!"

check_factory_v2:
	@echo "Checking DaosWorldFactoryV2 deployment"
	@forge script script/Deployer.s.sol:DaosWorldFactoryV2Script --rpc-url $(BASE_RPC_URL) --private-key $(PRIVATE_KEY) -vvvv

deploy_factory_4:
	@echo "Deploying DaoWorldFactory4V1 to Base Mainnet"
	@forge script script/Deployer.s.sol:DaoWorldFactory4Script --rpc-url $(BASE_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify -vvvvv --legacy
	@echo "Deployment completed!"

verify_dao_404:
	@echo "Verifying DaosWorldV1404 implementation"
	@forge verify-contract \
		--chain-id 8453 \
		--compiler-version v0.8.26 \
		--watch \
		--constructor-args $(shell cast abi-encode "constructor(uint256,string,string,uint256,uint256,address,address,uint256,address,uint256)" \
			"1000000000000000" \
			"Bear" \
			"Bear" \
			"1746978545" \
			"1751058145" \
			"0x0c0d274060766d0F8DcDebc8c4B305a3e8a676C0" \
			"0x21104fA3b456d9171D46996eE8Bfb377a936bf5d" \
			"1000000000000000000" \
			"0x0c0d274060766d0F8DcDebc8c4B305a3e8a676C0" \
			"1000000000000000") \
		0xaE890F4bc0B69D9734D9df2Fe7BAc9Db96689B31 \
		src/DaosWorldV1404.sol:DaosWorldV1404 \
		--libraries src/lib/TokenDistributionLib.sol:TokenDistributionLib:0xc0addCef4a3b7a491369055Da7313De082030bFc

make verify_404_token:
	@echo "Verifying DaosWorld404V1Token implementation"
	@forge verify-contract \
		--chain-id 8453 \
		--compiler-version v0.8.26 \
		--watch \
		--constructor-args $(shell cast abi-encode "constructor(string,string,string,uint8,uint256,address,address)" \
			"Bear" \
			"Bear" \
			"https://google.com" \
			"18" \
			"10000" \
			"0xaE890F4bc0B69D9734D9df2Fe7BAc9Db96689B31" \
			"0xaE890F4bc0B69D9734D9df2Fe7BAc9Db96689B31") \
		0x02eF5d8Ca8203867DCD4155911EDc9EE46ed467C \
		src/DaosWorld404V1Token.sol:DaosWorld404V1Token

deploy_locker_factory:
	@echo "Deploying LockerFactory to Base Mainnet"
	@forge script script/Deployer.s.sol:LockerFactoryScript --rpc-url $(BASE_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify -vvvvv --legacy
	@echo "Deployment completed!"

finalize_fundraising:
	@echo "Running FinalizeFundraising script on Base Mainnet"
	@forge script script/FinalizeFundraising.s.sol:FinalizeFundraisingScript \
		--rpc-url $(BASE_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		-vvvv \
		--legacy


deploy_factory_v2_vesting:
	@echo "Deploying DaosWorldFactoryV2Vesting to Base Mainnet"
	@forge script script/Deployer.s.sol:DaosWorldFactoryV2VestingScript --rpc-url $(BASE_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify -vvvvv --legacy
	@echo "Deployment completed!"

check_factory_v2_vesting:
	@echo "Checking DaosWorldFactoryV2Vesting deployment"
	@forge script script/Deployer.s.sol:DaosWorldFactoryV2VestingScript --rpc-url $(BASE_RPC_URL) --private-key $(PRIVATE_KEY) -vvvv


deploy_daos_world_pay_factory:
	@echo "Deploying DaosWorldPayFactory to Base Mainnet"
	@forge script script/Deployer.s.sol:DaosWorldPayFactoryScript --rpc-url $(BASE_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify -vvvvv --legacy
	@echo "Deployment completed!"

check_daos_world_pay_factory:
	@echo "Checking DaosWorldPayFactory deployment"
	@forge script script/Deployer.s.sol:DaosWorldPayFactoryScript --rpc-url $(BASE_RPC_URL) --private-key $(PRIVATE_KEY) -vvvv

deploy_dwl_converter:
	@echo "Deploying DWLConverter to Base Mainnet"
	@forge script script/Deployer.s.sol:DWLConverterScript --rpc-url $(BASE_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify -vvvvv --legacy
	@echo "Deployment completed!"

deploy_daos_world_tiers_factory:
	@echo "Deploying DaosWorldTiersFactory to Base Mainnet"
	@forge script script/Deployer.s.sol:DaosWorldTiersFactoryScript --rpc-url $(BASE_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify -vvvvv --legacy
	@echo "Deployment completed!"
