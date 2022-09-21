// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/* twitter @abdthedev_ */

interface IERC721{ // Auctiona cikarilan token NFT oldugu icin ERC721 interface olusturuyoruz. 
// Biz sadece token'ı transfer edeceğimiz için transferFrom fonksyionunu kullanacağız.
    function transferFrom(address from, address to, uint nftId) external;
}


contract EnglishAuction {
    event Start();
    event Bid(address indexed sender, uint amount); // bir sender tarafından gönderilecek bidlere ulasmak isteyebiliriz. bundan dolayı addressi indexledik
    event Withdraw(address indexed bidder, uint amount);
    event End(address highestBidder, uint highestBid);
    
    IERC721 public immutable nft; // NFT tokenenin olusturulmasi.
    uint public immutable nftId; // olustulan NFT'nin ID'si.

    address payable public immutable seller;
    uint public immutable startingPrice;
    uint32 public  endAt; // 32 Bit ile yaklaşık 1000 yıl elde edebiliyoruz. Bir açık arttırma için yeter de artar.

    bool public started;
    bool public ended;

    address public highestBidder; // en yuksek bid'i kimin verdigini tutacak degisken 
    uint public highestBid; // en yuksek bidi tutacak degisken
    mapping(address => uint) public bids;  // hangi addressin ne kadar bid koydugunu gosteren mapping

    constructor( // yukarıda immutable olarak tanımlanan degiskenlerin hepsini burada tanımlamamız gerekiyor.
    address _nft,
     uint _nftId, 
     uint _startingBid){
        nft = IERC721(_nft); // olusturlan nft'nin adresini contract'a belirtiyoruz.
        nftId = _nftId;
        seller = payable(msg.sender); // contract'ı oluşturan kişi satıcı konumuna gelir.
        startingPrice = _startingBid; // baslangic bidinden fiyat baslar.


    }

    function start() external{ // auction'u baslatan fonksyion.
        require(msg.sender == seller, "not seller"); // auction'u sadece satıcı baslatabilir.
        require(!started, "started"); // auction'un baslamasi icin, henuz baslamamiz olmasi gerekir.
        started = true;
        endAt = uint32(block.timestamp + 60); // block.timestamp uint256 oldugu icin uint32'ye cast ediyoruz. 
                                              // + 60 dedigimiz icin bu auction 60 saniye sürecek.
        nft.transferFrom(seller, address(this), nftId); // satıcının sahip oldugu NFT bu contract'a transfer ediliyor.
        emit Start(); // Start eventi atesleniyor.
    }

    function bid() external payable {
        require(started, "Not started");
        require(block.timestamp < endAt, "Auction ended");
        require(msg.value > highestBid, "Your bid is less then the highest bid"); // English Auction oldugu icin gelecek bidin son bidden yuksek olmasi gerekiyor.

        if (highestBidder != address(0)){ // ilk teklif geldiginde highestBidder addresi address 0 olacağı için aşağıdaki kodun address 0 hariç calismaisini saglamak istiyoruz
            bids[highestBidder] += highestBid; // yeni bid geldiginde onceki bidi sahipine iade etmemiz gerekir. bunun takibini yapmak için mapping kullandık.
                                                // bu kod tüm bidleri tutacak böylece withdraw edebilecekler.
        }
        // en yuksek bid ve sahibi atanır.
        highestBid = msg.value;
        highestBidder = msg.sender;
        emit Bid(msg.sender, msg.value); // bid islemi basarili olursa bid eventi ateşlenir.
    }

    function withdraw() external { // out bid edilen addreslerin paralarını geri ceklemeleri saglayan fonksiyon.
        uint bal = bids[msg.sender]; // address tarafından gönderilen toplam bidlerin hesaplanması.
        bids[msg.sender] = 0; //re-enterency attacktan korunmak icin bunu yaptik.
        payable(msg.sender).transfer(bal);
        emit Withdraw(msg.sender, bal);
    }

    function end() external { // bu fonksiyonu sadece seller tarafından kullanılmasını istemiyoruz çünkü seller bu fonksiyonu cagirmazsa auction bitmez ve NFT bu contractta hapsolur.
        require(started, "not started");
        require(!ended, "ended");
        require (block.timestamp >= endAt, "not ended");
        
        ended = true;
        if (highestBidder != address(0)){ // kimse nft'ye bid koymazsa highestBidder address(0) olarak kalıcak ve nftimizi kaybedicez. bunu önlemek için böyle bir şey yaptık.
            nft.transferFrom(address(this), highestBidder , nftId);
            seller.transfer(highestBid); // verilen ucreti saticiya transfer ediyoruz.
        }
        else{ // kimse bid koymazsa nft seller'a geri dönecek.
            nft.transferFrom(address(this), seller, nftId);
        }
        emit End(highestBidder,  highestBid);
    }

}