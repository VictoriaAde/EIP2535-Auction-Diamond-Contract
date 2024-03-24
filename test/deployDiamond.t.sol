// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";

import "forge-std/Test.sol";
import "../contracts/facets/AUC20Facet.sol";
import "../contracts/facets/AuctionFacet.sol";
import "../contracts/RokiMarsNFT.sol";

contract DiamondDeployer is Test, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    AUC20Facet auctoken;
    AuctionFacet aucFacet;
    RokiMarsNFT rokiNFT;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        auctoken = new AUC20Facet();
        aucFacet = new AuctionFacet();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        A = mkaddr("staker a");
        B = mkaddr("staker b");
        C = mkaddr("staker c");

        //mint test tokens
        AUC20Facet(address(diamond)).mintTo(A);
        AUC20Facet(address(diamond)).mintTo(B);

        boundAuction = AuctionFacet(address(diamond));
        boundERC = AUC20Facet(address(diamond));

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("AUC20Facet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("AUC20Facet")
            })
        );

        cut[3] = (
            FacetCut({
                facetAddress: address(aucFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("AuctionFacet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function shouldRevertIfTokenAddressIsZero() public {
        vm.expectRevert("INVALID_CONTRACT_ADDRESS");
        boundAuction.createAuction(address(0), 1, 1e18, 2 days);
    }

    function shouldRevertIfNotTokenOwner() public {
        switchSigner(A);
        erc721Token.mint();
        switchSigner(B);
        vm.expectRevert("NOT_OWNER");
        boundAuction.createAuction(address(erc721Token), 1, 1e18, 2 days);
    }

    function shouldRevertIfInsufficientTokenBalance() public {
        switchSigner(C);
        erc721Token.mint();
        erc721Token.approve(address(diamond), 1);
        boundAuction.createAuction(address(erc721Token), 1, 1e18, 2 days);
        vm.expectRevert("INSUFFICIENT_BALANCE");
        boundAuction.bid(0, 5e18);
    }

    function shouldRevertIfBidAmountIsLessThanAuctionStartPrice() public {
        switchSigner(A);
        erc721Token.mint();
        erc721Token.approve(address(diamond), 1);
        boundAuction.createAuction(address(erc721Token), 1, 2e18, 2 days);
        vm.expectRevert("STARTING_PRICE_MUST_BE_GREATER");
        boundAuction.bid(0, 1e18);
    }

    function shouldRevertIfBidAmountIsLessThanLastBiddedAmount() public {
        switchSigner(A);
        erc721Token.mint();
        erc721Token.approve(address(diamond), 1);
        boundAuction.createAuction(address(erc721Token), 1, 2e18, 2 days);
        boundAuction.bid(0, 2e18);
        vm.expectRevert("PRICE_MUST_BE_GREATER_THAN_LAST_BIDDED");
        boundAuction.bid(0, 1e18);
    }

    function testBids() public {
        switchSigner(A);
        erc721Token.mint();
        erc721Token.approve(address(diamond), 1);
        boundAuction.startAuction(1, 2e18);
        boundAuction.placeBid(0, 2e18);
        switchSigner(B);
        boundAuction.bid(0, 3e18);
        LibAppStorage.Bid[] memory bids = boundAuction.getBid(0);
        assertEq(bids.length, 2);
        assertEq(bids[0].author, A);
        assertEq(bids[0].amount, 2e18);
        assertEq(bids[1].author, B);
        assertEq(bids[1].amount, (3e18 - ((10 * 3e18) / 100)));
    }

    function generateSelectors(
        string memory _facetName
    ) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
