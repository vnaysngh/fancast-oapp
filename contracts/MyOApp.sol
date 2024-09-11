// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, MessagingFee, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

contract MyOApp is OApp {
    struct Story {
        uint256 id;
        address author;
        string name;
        string description;
    }
    uint256 public nextStoryId = 1;
    mapping(uint256 => Story) public stories;
    uint256 public totalStories;
    using OptionsBuilder for bytes;
    bytes options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

    event StoryCreated(uint256 indexed id, address indexed author, string name, string description);
    event StoryReceived(uint256 id, address author, string name, string description, uint16 srcChainId);
    constructor(address _endpoint, address _delegate) OApp(_endpoint, _delegate) Ownable(_delegate) {}

    function quote(
        string memory _name,
        string memory _description,
        uint32[] memory _dstChainIds
    ) public view returns (MessagingFee memory totalFee) {
        Story memory newStory = Story(nextStoryId, msg.sender, _name, _description);
        bytes memory payload = abi.encode(newStory);

        for (uint i = 0; i < _dstChainIds.length; i++) {
            MessagingFee memory fee = _quote(_dstChainIds[i], payload, options, false);
            totalFee.nativeFee += fee.nativeFee;
            totalFee.lzTokenFee += fee.lzTokenFee;
        }

        return totalFee;
    }

    function createStory(
        string memory _name,
        string memory _description,
        uint32[] memory _dstChainIds
    ) external payable {
        // Calculate the total messaging fee required.
        MessagingFee memory totalFee = quote(_name, _description, _dstChainIds);
        require(msg.value >= totalFee.nativeFee, "Insufficient fee provided");

        uint256 newStoryId = nextStoryId++;
        Story memory newStory = Story(newStoryId, msg.sender, _name, _description);
        stories[newStoryId] = newStory;
        totalStories++;

        // Encodes the message before invoking _lzSend.
        bytes memory payload = abi.encode(newStory);

        uint256 totalNativeFeeUsed = 0;
        uint256 remainingValue = msg.value;

        for (uint i = 0; i < _dstChainIds.length; i++) {
            MessagingFee memory fee = _quote(_dstChainIds[i], payload, options, false);
            totalNativeFeeUsed += fee.nativeFee;
            remainingValue -= fee.nativeFee;
            require(remainingValue >= 0, "Insufficient fee for this destination");

            _lzSend(_dstChainIds[i], payload, options, MessagingFee(msg.value, 0), payable(msg.sender));
        }
    }

    function _lzReceive(Origin calldata, bytes32, bytes calldata payload, address, bytes calldata) internal override {
        Story memory receivedStory = abi.decode(payload, (Story));

        if (stories[receivedStory.id].id == 0) {
            stories[receivedStory.id] = receivedStory;
            totalStories++;

            if (receivedStory.id >= nextStoryId) {
                nextStoryId = receivedStory.id + 1;
            }

            // emit StoryReceived(receivedStory.id, receivedStory.author, receivedStory.name, receivedStory.description);
        }
    }

    function getStory(uint256 _storyId) external view returns (Story memory) {
        return stories[_storyId];
    }

    function getTotalStories() external view returns (uint256) {
        return totalStories;
    }

    function getAllStories() external view returns (Story[] memory) {
        Story[] memory allStories = new Story[](totalStories);
        uint256 index = 0;
        for (uint256 i = 1; i < nextStoryId; i++) {
            if (stories[i].id != 0) {
                allStories[index] = stories[i];
                index++;
            }
        }
        return allStories;
    }

    /**
     * @notice Quotes the gas needed to pay for the full omnichain transaction in native gas or ZRO token.
     * @param _dstEid Destination chain's endpoint ID.
     * @param _message The message.
     * @param _options Message execution options (e.g., for sending gas to destination).
     * @param _payInLzToken Whether to return fee in ZRO token.
     * @return fee A `MessagingFee` struct containing the calculated gas fee in either the native token or ZRO token.
     */
    function quote(
        uint32 _dstEid,
        string memory _message,
        bytes memory _options,
        bool _payInLzToken
    ) public view returns (MessagingFee memory fee) {
        bytes memory payload = abi.encode(_message);
        fee = _quote(_dstEid, payload, _options, _payInLzToken);
    }
}
