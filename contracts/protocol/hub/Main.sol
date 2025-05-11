// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Main is Ownable { 
    //platform users names
    mapping  (address => string) public userNames;

    //platform users addresses
    mapping (string => address[]) public usersAddresses;

    //check if registered
    mapping(address => bool) private isUser;

    //pause locking
    bool public pause;

    //events
    event RegisterUser (address indexed account, string name) ;
    event SetUsername(string oldName , string newName); 

    constructor() Ownable(msg.sender) {
        pause = false;
    }

    /*
    *@notice Implements user registration
    *@param _username The name for the wallet address
    *@dev enables us to calculate platform analytics
    */
    function registerUser(string memory _name) external {
        require(!isUser[msg.sender], "You are already registered!");

        userNames[msg.sender] = _name;
        usersAddresses["PU"].push(msg.sender);
        isUser[msg.sender] = true;

        emit RegisterUser (msg.sender, _name);
    }

    /*
    *@notice Fetched the username of an account from the address
    *@param _account The address to the fetch the username for
    */
    function getUsername(address _account) external view returns (string memory) {
        return  userNames[_account];
    }

    /*
    *@notice Sets the username of a particular address
    *@param _account The address to the fetch the username for
    */
    function setUsername(string memory _name) external {
        string memory oldName = userNames[msg.sender];
        userNames[msg.sender] = _name;

        emit SetUsername(oldName, _name);
    }

    /*
    *@notice Fetches registered users
    */
    function getRegisteredUsers() public view returns (address[] memory) {
        return usersAddresses["PU"];
    }

    /*
    *@notice Checked if an address is registered as a user
    */
    function checkIfRegistered() public view returns (bool) {
        return isUser[msg.sender];
    }

    /*
    *@notice Pause contracts
    */
    function pauseContracts() external onlyOwner{
        require(!pause, "Contract already paused!"); 
        pause = true;
    }

    /*
    *@notice Unpause contracts
    */
    function unPauseContracts() external onlyOwner{
        require(pause, "Contract already unpaused!"); 
        pause = false;
    }
}