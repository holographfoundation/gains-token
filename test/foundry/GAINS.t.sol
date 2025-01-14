// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// OApp / OFT imports
import { IOAppOptionsType3 } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { IOFT, SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

// OZ imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Forge imports
import "forge-std/console.sol";
import "forge-std/Test.sol";

// DevTools imports (your existing test-devtools-evm-foundry might differ)
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

// GAINS import
import { GAINS } from "../../src/GAINS.sol"; // adjust path as needed

// (Optional) If you have a mock "OFTComposerMock" you want to reuse for compose tests
import { OFTComposerMock } from "../mocks/OFTComposerMock.sol";

/**
 * @title GAINSTest
 * @notice Example test adapted from your OFTMock test suite to use GAINS.
 */
contract GAINSTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    GAINS private aGAINS;
    GAINS private bGAINS;

    address private userA = makeAddr("userA");
    address private userB = makeAddr("userB");
    uint256 private initialBalance = 100 ether;

    function setUp() public virtual override {
        // give userA / userB some native gas for sending
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);

        // set up endpoints, from your existing test harness
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        /**
         * Deploy a GAINS instance to represent chain A,
         * and another GAINS instance to represent chain B.
         *
         * _deployOApp is your test harness function that:
         * 1) Deploys the contract at the chain's endpoint
         * 2) Wires the contract into your local test environment
         *
         * GAINS constructor signature is:
         *   constructor(
         *     string memory _name,
         *     string memory _symbol,
         *     address _lzEndpoint,
         *     address _delegate
         *   )
         *
         * For testing, we can pass `address(this)` as the owner/delegate.
         */
        aGAINS = GAINS(
            _deployOApp(
                type(GAINS).creationCode,
                abi.encode("aGAINS", "aGAINS", address(endpoints[aEid]), address(this))
            )
        );
        bGAINS = GAINS(
            _deployOApp(
                type(GAINS).creationCode,
                abi.encode("bGAINS", "bGAINS", address(endpoints[bEid]), address(this))
            )
        );

        // wire the GAINS contracts so they can send cross-chain messages
        address[] memory ofts = new address[](2);
        ofts[0] = address(aGAINS);
        ofts[1] = address(bGAINS);
        this.wireOApps(ofts);

        // For local testing, we can use a helper "testMint" added in GAINS
        aGAINS.testMint(userA, initialBalance);
        bGAINS.testMint(userB, initialBalance);
    }

    function test_constructor() public view {
        // GAINS extends OFT which extends Ownable
        assertEq(aGAINS.owner(), address(this));
        assertEq(bGAINS.owner(), address(this));

        // check the minted balances we set up
        assertEq(aGAINS.balanceOf(userA), initialBalance);
        assertEq(bGAINS.balanceOf(userB), initialBalance);
    }

    /**
     * @notice Simple cross-chain send from chain A to chain B
     */
    function test_send_oft() public {
        uint256 tokensToSend = 1 ether;
        // build LayerZero "options" for gas, etc.
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

        // standard cross-chain send param
        SendParam memory sendParam = SendParam(
            bEid, // destination endpoint ID
            addressToBytes32(userB), // receiver on destination
            tokensToSend, // amount in local decimals
            tokensToSend, // min amount out
            options, // LZ receive options
            "", // optional compose message
            "" // adapter params
        );

        MessagingFee memory fee = aGAINS.quoteSend(sendParam, false);

        // check pre-send balances
        assertEq(aGAINS.balanceOf(userA), initialBalance);
        assertEq(bGAINS.balanceOf(userB), initialBalance);

        // userA sends tokens from chain A to chain B
        vm.prank(userA);
        aGAINS.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));

        // verify cross-chain packets in your test harness
        verifyPackets(bEid, addressToBytes32(address(bGAINS)));

        // check post-send balances
        assertEq(aGAINS.balanceOf(userA), initialBalance - tokensToSend);
        assertEq(bGAINS.balanceOf(userB), initialBalance + tokensToSend);
    }

    /**
     * @notice Cross-chain send with a "compose" message, calling a contract on the destination.
     * This is the same logic you had in your original test with `OFTComposerMock`.
     */
    function test_send_oft_compose_msg() public {
        uint256 tokensToSend = 1 ether;

        // reuse existing composer
        OFTComposerMock composer = new OFTComposerMock();

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0)
            .addExecutorLzComposeOption(0, 500000, 0);

        // just an example payload
        bytes memory composeMsg = hex"1234";

        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(address(composer)),
            tokensToSend,
            tokensToSend,
            options,
            composeMsg,
            ""
        );
        MessagingFee memory fee = aGAINS.quoteSend(sendParam, false);

        assertEq(aGAINS.balanceOf(userA), initialBalance);
        assertEq(bGAINS.balanceOf(address(composer)), 0);

        vm.prank(userA);
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = aGAINS.send{ value: fee.nativeFee }(
            sendParam,
            fee,
            payable(address(this))
        );
        verifyPackets(bEid, addressToBytes32(address(bGAINS)));

        // lzCompose params for your test harness
        uint32 dstEid_ = bEid;
        address from_ = address(bGAINS);
        bytes memory options_ = options;
        bytes32 guid_ = msgReceipt.guid;
        address to_ = address(composer);
        bytes memory composerMsg_ = OFTComposeMsgCodec.encode(
            msgReceipt.nonce,
            aEid,
            oftReceipt.amountReceivedLD,
            abi.encodePacked(addressToBytes32(userA), composeMsg)
        );

        // Manually call lzCompose (test harness) to simulate chain B receiving
        this.lzCompose(dstEid_, from_, options_, guid_, to_, composerMsg_);

        // verify final balances
        assertEq(aGAINS.balanceOf(userA), initialBalance - tokensToSend);
        assertEq(bGAINS.balanceOf(address(composer)), tokensToSend);

        // check composer state
        assertEq(composer.from(), from_);
        assertEq(composer.guid(), guid_);
        assertEq(composer.message(), composerMsg_);
        assertEq(composer.executor(), address(this));
        assertEq(composer.extraData(), composerMsg_);
    }
}
