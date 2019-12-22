pragma solidity ^0.5.0;
import "./res/SafeMath.sol";
import "./res/DateTime.sol";

// TD08 monnaie-numerique at ESILV
// contract to manage concert ticketing

contract ticketingSystem {
    using SafeMath for uint;
    using SafeMath for uint;

    /// VARS

    address private contractOwner; // address of the owner of this contract == ADMIN
    DateTime dt; // time manager

    // artists
    struct _ARTIST {
        string name; // name of the artist
        uint artistCategory; // genre/category
        uint totalTicketSold; // n of sold tickets
        address payable owner; // owner address of this artist
    }
    mapping (uint => _ARTIST) public artistsRegister; // list of artists
    uint private artistCounter; // counter of artists

    // venues
    struct _VENUE {
        string name; // name of the venue
        uint capacity; // max available space
        uint standardComission; // % of the ticket for the venue * 100 (two decimals)
        address payable owner; // owner address of this venue

    }
    mapping (uint => _VENUE) public venuesRegister; // list of venues
    uint private venueCounter; // counter of venues

    // concerts
    struct _CONCERT {
        uint artistId; // artist
        uint venueId; // venue
        uint concertDate; // timeStamp

        // tickets
        uint ticketPrice;
        uint venueComission; // comission for venue
        uint totalTickets;
        uint totalSoldTicket;
        uint totalMoneyCollected;

        // flags
        bool validatedByArtist; // true if event validated by artist
        bool validatedByVenue; // true if event validated by venue
        bool cashOutFlag; // true if cashout already paid to artist/venue
    }
    mapping (uint => _CONCERT) public concertsRegister; // list of concerts
    uint private concertCounter; // counter of concerts

    // tickets
    struct _TICKET {
        uint concertId;
        address payable owner;
        uint amountPaid;
        uint salePrice;
        string promoCode;
        // flags
        bool isAvailable;
        bool isAvailableForSale;
        bool isAvailableForPromo;
    }
    mapping (uint => _TICKET) public ticketsRegister; // list of tickets
    uint private ticketCounter; // counter of tickets


    /// CONSTRUCTOR

    constructor() public {
        concertCounter = 0;
        artistCounter = 0;
        venueCounter = 0;
        contractOwner = msg.sender;
        dt = new DateTime();
    }


    /// EVENTS

    event ArtistCreated(uint ArtistId, string Name, uint Genre);

    event VenueCreated(uint VenueId, string Name, uint MaxSpace, uint StardardComission);

    event ConcertDeclared(uint ConcertId, string Artist, string Venue,
                          uint Year, uint Month, uint Day, uint Hour, uint Minute);

    event ConcertValidated(uint ConcertId, string Artist, string Venue,
                           uint Year, uint Month, uint Day, uint Hour, uint Minute,
                           uint TicketPrice, uint AvailableTickets);

    event TicketEmitted(uint TicketId, string Artist, string Venue,
                        address payable Owner,
                        uint StillAvailableTickets);

    event TicketUsed(uint TicketId, string Artist, string Venue, address Owner);

    event TicketForSale(uint TicketId, string Artist, string Venue);


    /// FUNCTIONS

    function createArtist(string memory name, uint category) public {
        artistCounter++;
        artistsRegister[artistCounter].name = name;
        artistsRegister[artistCounter].artistCategory = category;
        artistsRegister[artistCounter].totalTicketSold = 0;
        // set creator as artistOwner
        artistsRegister[artistCounter].owner = msg.sender;
        // emit event
        /* emit ArtistCreated(artistCounter, name, category); */
    }


    function modifyArtist(uint artistId, string memory newName, uint newCategory, address payable newOwner) public {
        require(msg.sender == artistsRegister[artistId].owner || msg.sender == contractOwner,
                "You don't have the permission to modify this artist.");
        artistsRegister[artistId].name = newName;
        artistsRegister[artistId].artistCategory = newCategory;
        artistsRegister[artistId].owner = newOwner;
        // ticketBalance shouldn't be touched in this case
    }

    function createVenue(string memory name, uint capacity, uint comission) public {
        venueCounter++;
        venuesRegister[venueCounter].name = name;
        venuesRegister[venueCounter].capacity = capacity;
        venuesRegister[venueCounter].standardComission = comission;
        // set creator as venue owner
        venuesRegister[venueCounter].owner = msg.sender;
        // emit event
        /* emit VenueCreated(venueCounter, name, capacity, comission); */
    }

    function modifyVenue(uint venueId, string memory newName, uint newCapacity, uint newComission, address payable newOwner) public {
        require(msg.sender == venuesRegister[venueId].owner || msg.sender == contractOwner,
                "You don't have the permission to modify this venue.");
        venuesRegister[venueId].name = newName;
        venuesRegister[venueId].capacity = newCapacity;
        venuesRegister[venueId].standardComission = newComission;
        venuesRegister[venueId].owner = newOwner;
    }


    function createConcert(uint artistId, uint venueId, uint date, uint ticketPrice) public {
        // anybody can organize a concert declaring all the details
        // concert must be confirmed by artist and venue
        concertCounter++;
        concertsRegister[concertCounter].artistId = artistId;
        concertsRegister[concertCounter].venueId = venueId;
        concertsRegister[concertCounter].ticketPrice = ticketPrice;
        concertsRegister[concertCounter].concertDate = date;
        concertsRegister[concertCounter].venueComission = venuesRegister[venueId].standardComission;
        concertsRegister[concertCounter].totalTickets = venuesRegister[venueId].capacity;
        concertsRegister[concertCounter].totalSoldTicket = 0;
        concertsRegister[concertCounter].totalMoneyCollected = 0;
        concertsRegister[concertCounter].validatedByArtist = false;
        concertsRegister[concertCounter].validatedByVenue = false;
        concertsRegister[concertCounter].cashOutFlag = false;
        // if the declator is the artist of the venue owner set the concert already validated
        if (msg.sender == artistsRegister[artistId].owner) {
            concertsRegister[concertCounter].validatedByArtist = true;
        }
        if (msg.sender == venuesRegister[venueId].owner) {
            concertsRegister[concertCounter].validatedByVenue = true;
        }
        // emit event
        /* emit ConcertDeclared(concertCounter,
                             artistsRegister[artistId].name,
                             venuesRegister[venueId].name,
                             dt.getYear(date),
                             dt.getMonth(date),
                             dt.getDay(date),
                             dt.getHour(date),
                             dt.getMinute(date)); */
    }

    function validateConcert(uint concertId) public {
        require(msg.sender == artistsRegister[concertsRegister[concertId].artistId].owner ||
                msg.sender == venuesRegister[concertsRegister[concertId].venueId].owner,
                "Only artist and venue have to validate the concert.");
        require(now < concertsRegister[concertId].concertDate,
                "Date of the concert is expired.");

        if (msg.sender == artistsRegister[concertsRegister[concertId].artistId].owner) {
            concertsRegister[concertId].validatedByArtist = true;
        }
        if (msg.sender == venuesRegister[concertsRegister[concertId].venueId].owner) {
            concertsRegister[concertId].validatedByVenue = true;
        }
        /*
        if (concertsRegister[concertId].validatedByVenue &&
            concertsRegister[concertId].validatedByArtist) {
            emit ConcertValidated(concertId,
                                  artistsRegister[concertsRegister[concertId].artistId].name,
                                  venuesRegister[concertsRegister[concertId].venueId].name,
                                  dt.getYear(concertsRegister[concertId].concertDate),
                                  dt.getMonth(concertsRegister[concertId].concertDate),
                                  dt.getDay(concertsRegister[concertId].concertDate),
                                  dt.getHour(concertsRegister[concertId].concertDate),
                                  dt.getMinute(concertsRegister[concertId].concertDate),
                                  concertsRegister[concertId].ticketPrice,
                                  concertsRegister[concertId].totalTickets - concertsRegister[concertId].totalSoldTicket);
        }*/
    }

    function createTicket(uint concertId, address payable receiver, uint amountPaid) private {
        // private function to create ticket
        ticketCounter++;
        ticketsRegister[ticketCounter].concertId = concertId;
        ticketsRegister[ticketCounter].owner = receiver;
        ticketsRegister[ticketCounter].isAvailable = true;
        ticketsRegister[ticketCounter].isAvailableForSale = false;
        ticketsRegister[ticketCounter].amountPaid = amountPaid;
        ticketsRegister[ticketCounter].isAvailableForPromo = false;
        ticketsRegister[ticketCounter].promoCode = '0';
        // account ticket
        concertsRegister[concertId].totalSoldTicket++;
    }

    function emitTicket(uint concertId, address payable receiver) public {
        // artist can emit a ticket for free
        require(msg.sender == artistsRegister[concertsRegister[concertId].artistId].owner,
                "Only artist can emit tickets for free.");
        require(concertsRegister[concertId].totalTickets - concertsRegister[concertId].totalSoldTicket > 0,
                "Concert is sold out.");
        // emit ticket
        createTicket(concertId, receiver, 0); // ticketCounter is incremented here
        // emit event
        /*emit TicketEmitted(ticketCounter,
                           artistsRegister[concertsRegister[concertId].artistId].name,
                           venuesRegister[concertsRegister[concertId].venueId].name,
                           receiver,
                           concertsRegister[concertId].totalTickets - concertsRegister[concertId].totalSoldTicket);*/
    }

    function buyTicket(uint concertId) public payable {
        require(msg.value >= concertsRegister[concertId].ticketPrice,
                "Payment refused.");
        require(concertsRegister[concertId].totalTickets - concertsRegister[concertId].totalSoldTicket > 0,
                "Concert is sold out.");
        // emit ticket
        createTicket(concertId, msg.sender, concertsRegister[concertId].ticketPrice); // ticketCounter is incremented here
        // account ticket
        concertsRegister[concertId].totalMoneyCollected += msg.value;
        artistsRegister[concertsRegister[concertId].artistId].totalTicketSold++;
        // emit event
        /* emit TicketEmitted(ticketCounter,
                           artistsRegister[concertsRegister[concertId].artistId].name,
                           venuesRegister[concertsRegister[concertId].venueId].name,
                           msg.sender,
                           concertsRegister[concertId].totalTickets - concertsRegister[concertId].totalSoldTicket); */
    }

    function useTicket(uint ticketId) public {
        // ticket is usable the day before the concert by the owner
        require(ticketsRegister[ticketId].owner == msg.sender,
                "You are not the owner of this ticket.");
        require(now > concertsRegister[ticketsRegister[ticketId].concertId].concertDate - 60*60*24,
                "There is a time and place for everything. Not now. (It's too early) (The reason could be an imprecision of block.timestamp, if you think so try again)");
        require(now < concertsRegister[ticketsRegister[ticketId].concertId].concertDate,
                "There is a time and place for everything. Not now. (It's too late.) (The reason could be an imprecision of block.timestamp, if you think so try again)");
        require(concertsRegister[ticketsRegister[ticketId].concertId].validatedByArtist &&
                concertsRegister[ticketsRegister[ticketId].concertId].validatedByVenue,
                "This concert is not validated.");
        require(ticketsRegister[ticketId].isAvailable,
                "This concert is not available anymore.");
        // set ticket as not available anymore
        ticketsRegister[ticketId].isAvailable = false;
        // set the owner as address 0x0000
        ticketsRegister[ticketId].owner = address(0);
        // emit event
        /* emit TicketUsed(ticketId,
                        artistsRegister[concertsRegister[ticketsRegister[ticketId].concertId].artistId].name,
                        venuesRegister[concertsRegister[ticketsRegister[ticketId].concertId].venueId].name,
                        msg.sender); */
    }


    function transferTicket(uint ticketId, address payable receiver) public {
        // the owner can transfer the property of the ticket to anyone
        require(msg.sender == ticketsRegister[ticketId].owner,
                "You are not the owner of this ticket.");
        ticketsRegister[ticketId].owner = receiver;
    }

    function cashOutConcert(uint concertId, address payable receiver) public {
        // only artist can ask for his money after the concert
        // it automatically gives the agreed percentage to venue
        require(msg.sender == artistsRegister[concertsRegister[concertId].artistId].owner,
                "Only the artist can require the cash out");
        require(now > concertsRegister[concertId].concertDate,
                "There is a time and place for everything. Not now. (It's too early) (The reason could be an imprecision of block.timestamp, if you think so try again)");
        require(concertsRegister[concertId].cashOutFlag == false,
                "Cash out already done.");
        // pay artist
        receiver.transfer(concertsRegister[concertId].totalMoneyCollected *
                          (10000 - concertsRegister[concertId].venueComission) / 10000);
        // pay venue
        venuesRegister[concertsRegister[concertId].venueId].owner.transfer(concertsRegister[concertId].totalMoneyCollected *
                                                                           concertsRegister[concertId].venueComission / 10000);
        // set cashout flag
        concertsRegister[concertId].cashOutFlag = true;
    }


    function offerTicketForSale(uint ticketId, uint salePrice) public {
        // anyone can sell ticket his owns
        // it's forbidden to sell the ticket for more than the concert price
        require(msg.sender == ticketsRegister[ticketId].owner,
                "You are not the owner of this ticket.");
        require(salePrice <= ticketsRegister[ticketId].amountPaid,
                "It's forbidden to sell a ticket for more than the value you bought it.");
        // set ticket for sale
        ticketsRegister[ticketId].isAvailableForSale = true;
        ticketsRegister[ticketId].salePrice = salePrice;
        // emit event
        /* emit TicketForSale(ticketId,
                           artistsRegister[concertsRegister[ticketsRegister[ticketId].concertId].artistId].name,
                           venuesRegister[concertsRegister[ticketsRegister[ticketId].concertId].venueId].name); */
    }


    function buySecondHandTicket(uint ticketId) public payable {
        require(ticketsRegister[ticketId].isAvailableForSale,
                "This ticket is not for sale or it's already sold.");
        require(ticketsRegister[ticketId].isAvailable,
                "This ticket is not available, probably it is already used.");
        require(msg.value >= ticketsRegister[ticketId].salePrice,
                "Payment refused.");
        // pay seller
        ticketsRegister[ticketId].owner.transfer(msg.value);
        // change owner
        ticketsRegister[ticketId].owner = msg.sender;
        // set the ticket as no more for sale
        ticketsRegister[ticketId].isAvailableForSale = false;
    }

    function distributePromoTicket(uint concertId, string memory promoCode) public {
        // artist can distribute promo tickets
        require(msg.sender == artistsRegister[concertsRegister[concertId].artistId].owner,
                "Only artist can emit tickets for free.");
        require(concertsRegister[concertId].totalTickets - concertsRegister[concertId].totalSoldTicket > 0,
                "Concert is sold out.");
        // create ticket and set address zero as owner
        createTicket(concertId, address(0), 0); // ticketCounter is incremented here
        // set promoCode
        ticketsRegister[ticketCounter-1].promoCode = promoCode;
        ticketsRegister[ticketCounter-1].isAvailableForPromo = true;
    }

    function redeemPromoTicket(uint ticketId, string memory promoCode) public {
        require(keccak256(abi.encodePacked((ticketsRegister[ticketId].promoCode))) == keccak256(abi.encodePacked((promoCode))),
                "Promo code is not valid.");
        require(ticketsRegister[ticketId].isAvailableForPromo,
                "This ticket is not a promo ticket.");
        // change owner
        ticketsRegister[ticketId].owner = msg.sender;
        // set the ticket as no more for promo
        ticketsRegister[ticketId].isAvailableForPromo = false;
    }

}


