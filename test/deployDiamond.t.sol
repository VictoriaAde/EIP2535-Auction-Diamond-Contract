// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/libraries/LibAppStorage.sol";

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
    AUC20Facet aucToken;
    AuctionFacet aucFacet;
    RokiMarsNFT rokiNFT;

    LibAppStorage.Layout internal l;

    address A = address(0xa);
    address B = address(0xb);
    address C = address(0xc);

    AuctionFacet boundAuction;
    AUC20Facet boundERC;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        aucToken = new AUC20Facet();
        aucFacet = new AuctionFacet();
        rokiNFT = new RokiMarsNFT();

        //upgrade diamond with facet
        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

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
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(aucToken),
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

        A = mkaddr("staker a");
        B = mkaddr("staker b");
        C = mkaddr("staker c");

        //mint test tokens
        AUC20Facet(address(diamond)).mintTo(A);
        AUC20Facet(address(diamond)).mintTo(B);

        boundAuction = AuctionFacet(address(diamond));
        boundERC = AUC20Facet(address(diamond));

        //call a function
        // DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    // function testShouldRevertIfLessThanZero() public {
    //     switchSigner(C);
    //     rokiNFT.mint();
    //     boundAuction.startAuction(1, 0);

    //     vm.expectRevert("Starting bid must be greater than zero");
    // }

    // function testShouldRevertIfInsufficientTokenBalance() public {
    //     switchSigner(C);
    //     rokiNFT.mint();
    //     rokiNFT.approve(address(diamond), 1);
    //     boundAuction.startAuction(1, 2e18);

    //     vm.expectRevert("INSUFFICIENT_BALANCE");
    //     boundAuction.placeBid(0, 5e18);
    // }

    // function testShouldRevertIfBidAmountIsLessThanAuctionStartPrice() public {
    //     switchSigner(A);
    //     rokiNFT.mint();
    //     rokiNFT.approve(address(diamond), 1);
    //     boundAuction.startAuction(1, 2e18);

    //     vm.expectRevert("Bid must be higher than the current highest bid");
    //     boundAuction.placeBid(0, 1e18);
    // }

    function testShouldRevertIfBidAmountIsLessThanLastBiddedAmount() public {
        switchSigner(A);
        rokiNFT.mint();
        rokiNFT.approve(address(diamond), 1);
        boundAuction.startAuction(1, 2e18);

        boundAuction.placeBid(0, 1e18);
        vm.expectRevert("PRICE_MUST_BE_GREATER_THAN_LAST_BIDDED");
        boundAuction.placeBid(0, 1e18);
    }

    // function testShouldSuccessfullyBid() public {
    //     switchSigner(A);
    //     rokiNFT.mint();
    //     rokiNFT.approve(address(diamond), 1);
    //     boundAuction.startAuction(1, 2e18);
    //     boundAuction.placeBid(0, 2e18);
    //     switchSigner(B);
    //     boundAuction.placeBid(0, 3e18);

    //     // LibAppStorage.Auction[] memory auctions = boundAuction.getBid(0);
    //     // LibAppStorage.Auction storage aucs = boundAuction.getBid(0);
    //     LibAppStorage.Auction storage aucs1 = l.auctions[0];
    //     LibAppStorage.Auction storage aucs2 = l.auctions[1];

    //     // assertEq(aucs.length, 2);
    //     assertEq(aucs1.owner, A);
    //     assertEq(aucs1.highestBid, 2e18);
    //     assertEq(aucs2.owner, B);
    //     assertEq(aucs2.highestBid, (3e18 - ((10 * 3e18) / 100)));
    // }

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

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
        vm.label(addr, name);
        return addr;
    }

    function switchSigner(address _newSigner) public {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }

        // uint256[] = new uint256[](2);
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
