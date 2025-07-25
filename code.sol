// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Neighborhood Safety Network
 * @dev A decentralized platform for community safety alerts and coordination
 * @author Neighborhood Safety Team
 */
contract Project {
    
    // Enums for alert classification
    enum AlertType { EMERGENCY, SUSPICIOUS, WEATHER, MISSING_PERSON, TRAFFIC, UTILITY }
    enum AlertStatus { ACTIVE, RESOLVED, FALSE_ALARM }
    
    // Core data structures
    struct Alert {
        uint256 id;
        address reporter;
        AlertType alertType;
        AlertStatus status;
        string location;
        string description;
        uint256 timestamp;
        uint256 latitude;
        uint256 longitude;
        uint256 radius;
        address[] responders;
        bool verified;
    }
    
    struct User {
        bool isRegistered;
        bool isVerified;
        bool isFirstResponder;
        uint256 reputationScore;
        uint256 alertsReported;
        uint256 alertsResponded;
        string contactInfo; // Encrypted contact details
    }
    
    struct Neighborhood {
        uint256 id;
        string name;
        uint256 centerLat;
        uint256 centerLng;
        uint256 radius;
        address[] residents;
        address moderator;
        bool isActive;
    }
    
    // State variables
    mapping(uint256 => Alert) public alerts;
    mapping(address => User) public users;
    mapping(uint256 => Neighborhood) public neighborhoods;
    mapping(address => bool) public emergencyServices;
    
    uint256 public alertCounter;
    uint256 public neighborhoodCounter;
    address public owner;
    
    // Constants
    uint256 public constant REPUTATION_REWARD = 10;
    uint256 public constant FALSE_ALARM_PENALTY = 25;
    uint256 public constant MIN_REPUTATION = 50;
    
    // Events
    event AlertCreated(uint256 indexed alertId, address indexed reporter, AlertType alertType, string location);
    event AlertResponded(uint256 indexed alertId, address indexed responder);
    event AlertResolved(uint256 indexed alertId, AlertStatus status);
    event UserRegistered(address indexed user);
    event UserVerified(address indexed user);
    event NeighborhoodCreated(uint256 indexed neighborhoodId, string name, address moderator);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyRegistered() {
        require(users[msg.sender].isRegistered, "User must be registered");
        _;
    }
    
    modifier onlyVerified() {
        require(users[msg.sender].isVerified, "User must be verified");
        _;
    }
    
    modifier validAlert(uint256 _alertId) {
        require(_alertId < alertCounter, "Invalid alert ID");
        require(alerts[_alertId].status == AlertStatus.ACTIVE, "Alert is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        alertCounter = 0;
        neighborhoodCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Create Safety Alert
     * @param _alertType Type of alert (Emergency, Suspicious, etc.)
     * @param _location Human-readable location description
     * @param _description Detailed description of the incident
     * @param _latitude Latitude coordinate (multiplied by 1e6 for precision)
     * @param _longitude Longitude coordinate (multiplied by 1e6 for precision)
     * @param _radius Alert radius in meters
     */
    function createAlert(
        AlertType _alertType,
        string memory _location,
        string memory _description,
        uint256 _latitude,
        uint256 _longitude,
        uint256 _radius
    ) external onlyRegistered {
        require(bytes(_location).length > 0, "Location cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_radius > 0 && _radius <= 5000, "Invalid radius (1-5000m)");
        require(users[msg.sender].reputationScore >= MIN_REPUTATION, "Insufficient reputation");
        
        uint256 alertId = alertCounter++;
        
        alerts[alertId] = Alert({
            id: alertId,
            reporter: msg.sender,
            alertType: _alertType,
            status: AlertStatus.ACTIVE,
            location: _location,
            description: _description,
            timestamp: block.timestamp,
            latitude: _latitude,
            longitude: _longitude,
            radius: _radius,
            responders: new address[](0),
            verified: users[msg.sender].isVerified
        });
        
        // Update user statistics
        users[msg.sender].alertsReported++;
        
        // Auto-verify emergency alerts from first responders
        if (_alertType == AlertType.EMERGENCY && users[msg.sender].isFirstResponder) {
            alerts[alertId].verified = true;
        }
        
        emit AlertCreated(alertId, msg.sender, _alertType, _location);
    }
    
    /**
     * @dev Core Function 2: Respond to Safety Alert
     * @param _alertId ID of the alert to respond to
     */
    function respondToAlert(uint256 _alertId) external onlyRegistered validAlert(_alertId) {
        Alert storage alert = alerts[_alertId];
        
        // Check if user already responded
        for (uint i = 0; i < alert.responders.length; i++) {
            require(alert.responders[i] != msg.sender, "Already responded to this alert");
        }
        
        // Add responder to the alert
        alert.responders.push(msg.sender);
        
        // Update user statistics and reputation
        users[msg.sender].alertsResponded++;
        users[msg.sender].reputationScore += REPUTATION_REWARD;
        
        emit AlertResponded(_alertId, msg.sender);
    }
    
    /**
     * @dev Core Function 3: Resolve Safety Alert
     * @param _alertId ID of the alert to resolve
     * @param _status Resolution status (RESOLVED or FALSE_ALARM)
     */
    function resolveAlert(uint256 _alertId, AlertStatus _status) external validAlert(_alertId) {
        require(_status != AlertStatus.ACTIVE, "Cannot set status to ACTIVE");
        
        Alert storage alert = alerts[_alertId];
        
        // Authorization check - only reporter, first responders, or emergency services can resolve
        require(
            msg.sender == alert.reporter ||
            users[msg.sender].isFirstResponder ||
            emergencyServices[msg.sender] ||
            msg.sender == owner,
            "Not authorized to resolve this alert"
        );
        
        // Update alert status
        alert.status = _status;
        
        // Handle reputation changes based on resolution
        if (_status == AlertStatus.FALSE_ALARM) {
            // Penalize false alarm reporter
            if (users[alert.reporter].reputationScore >= FALSE_ALARM_PENALTY) {
                users[alert.reporter].reputationScore -= FALSE_ALARM_PENALTY;
            } else {
                users[alert.reporter].reputationScore = 0;
            }
        } else if (_status == AlertStatus.RESOLVED) {
            // Reward valid alert reporter
            users[alert.reporter].reputationScore += REPUTATION_REWARD;
        }
        
        emit AlertResolved(_alertId, _status);
    }
    
    // User Management Functions
    function registerUser(string memory _contactInfo) external {
        require(!users[msg.sender].isRegistered, "User already registered");
        require(bytes(_contactInfo).length > 0, "Contact info required");
        
        users[msg.sender] = User({
            isRegistered: true,
            isVerified: false,
            isFirstResponder: false,
            reputationScore: MIN_REPUTATION,
            alertsReported: 0,
            alertsResponded: 0,
            contactInfo: _contactInfo
        });
        
        emit UserRegistered(msg.sender);
    }
    
    function verifyUser(address _user) external onlyOwner {
        require(users[_user].isRegistered, "User not registered");
        require(!users[_user].isVerified, "User already verified");
        
        users[_user].isVerified = true;
        users[_user].reputationScore += 25; // Verification bonus
        
        emit UserVerified(_user);
    }
    
    function setFirstResponder(address _user, bool _status) external onlyOwner {
        require(users[_user].isVerified, "User must be verified first");
        users[_user].isFirstResponder = _status;
    }
    
    function addEmergencyService(address _service) external onlyOwner {
        emergencyServices[_service] = true;
    }
    
    // Neighborhood Management
    function createNeighborhood(
        string memory _name,
        uint256 _centerLat,
        uint256 _centerLng,
        uint256 _radius
    ) external onlyVerified {
        require(bytes(_name).length > 0, "Neighborhood name required");
        require(_radius > 0, "Invalid radius");
        
        uint256 neighborhoodId = neighborhoodCounter++;
        
        neighborhoods[neighborhoodId] = Neighborhood({
            id: neighborhoodId,
            name: _name,
            centerLat: _centerLat,
            centerLng: _centerLng,
            radius: _radius,
            residents: new address[](0),
            moderator: msg.sender,
            isActive: true
        });
        
        neighborhoods[neighborhoodId].residents.push(msg.sender);
        
        emit NeighborhoodCreated(neighborhoodId, _name, msg.sender);
    }
    
    function joinNeighborhood(uint256 _neighborhoodId) external onlyRegistered {
        require(_neighborhoodId < neighborhoodCounter, "Invalid neighborhood ID");
        require(neighborhoods[_neighborhoodId].isActive, "Neighborhood not active");
        
        // Add user to neighborhood residents
        neighborhoods[_neighborhoodId].residents.push(msg.sender);
    }
    
    // View Functions
    function getAlert(uint256 _alertId) external view returns (Alert memory) {
        require(_alertId < alertCounter, "Invalid alert ID");
        return alerts[_alertId];
    }
    
    function getActiveAlerts() external view returns (uint256[] memory) {
        uint256[] memory activeAlerts = new uint256[](alertCounter);
        uint256 count = 0;
        
        for (uint256 i = 0; i < alertCounter; i++) {
            if (alerts[i].status == AlertStatus.ACTIVE) {
                activeAlerts[count] = i;
                count++;
            }
        }
        
        // Create properly sized return array
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = activeAlerts[i];
        }
        
        return result;
    }
    
    function getUserProfile(address _user) external view returns (User memory) {
        require(users[_user].isRegistered, "User not registered");
        return users[_user];
    }
    
    function getNeighborhood(uint256 _neighborhoodId) external view returns (Neighborhood memory) {
        require(_neighborhoodId < neighborhoodCounter, "Invalid neighborhood ID");
        return neighborhoods[_neighborhoodId];
    }
    
    function getAlertResponders(uint256 _alertId) external view returns (address[] memory) {
        require(_alertId < alertCounter, "Invalid alert ID");
        return alerts[_alertId].responders;
    }
    
    function getTotalAlerts() external view returns (uint256) {
        return alertCounter;
    }
    
    function getTotalNeighborhoods() external view returns (uint256) {
        return neighborhoodCounter;
    }
}
