// import NonFungibleToken from "../standards/NonFungibleToken.cdc";
// import MetadataViews from "../standards/MetadataViews.cdc";
import NonFungibleToken from 0xf8d6e0586b0a20c7
import MetadataViews from 0xf8d6e0586b0a20c7

pub contract Chapter2Bikes: NonFungibleToken {

  // Events
  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64)
  pub event NFTDestroyed(id: UInt64)

  // Named Paths
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let AdminStoragePath: StoragePath
  pub let AdminPrivatePath: PrivatePath

  // Contract Level Fields
  pub var totalSupply: UInt64
  pub var frameEditionSupply: UInt64
  pub var paintingEditionSupply: UInt64

  // Contract Level Composite Type Definitions

  // Each NFT is associated to an Edition/Type: Frame or Painting.
  pub enum Edition: UInt8 {
    pub case frame
    pub case painting
  }

  // Resource that represents the a Chapter2Bikes NFT
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64

    pub let edition: UInt8

    pub var metadata: {String: String}

    pub fun getViews(): [Type] {
      return [
          Type<MetadataViews.Display>()
      ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
          case Type<MetadataViews.Display>():
          return MetadataViews.Display(
              name: self.metadata["name"]!,
              description: self.metadata["description"]!,
              thumbnail: MetadataViews.HTTPFile(url: self.metadata["external_url"]!)
          )
      }
      return nil 
    }

    init(_edition: UInt8, _metadata: {String: String}) {
      self.id = Chapter2Bikes.totalSupply
      self.edition = _edition
      self.metadata = _metadata

      // Total Supply
      Chapter2Bikes.totalSupply = Chapter2Bikes.totalSupply + 1

      // Edition Supply
      if (_edition == 0) {
        Chapter2Bikes.frameEditionSupply = Chapter2Bikes.frameEditionSupply + 1
      } else if (_edition == 1) {
        Chapter2Bikes.paintingEditionSupply = Chapter2Bikes.paintingEditionSupply + 1
      } else {
        // Invalid Edition
        panic("Edition is invalid. Options: 0(Frame) or 1(Painting)")
      }

      // Emit Minted Event
      emit Minted(id: self.id)
    }
  }

  // Public Interface for Collection resource
  pub resource interface CollectionPublic {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowEntireNFT(id: UInt64): &Chapter2Bikes.NFT?
  }

  // Collection resource for managing Chapter2Bikes NFTs
  pub resource Collection: NonFungibleToken.Receiver, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, CollectionPublic {

    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
    
    // Withdraw
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Token not found")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <- token
    }

    // Deposit
    pub fun deposit(token: @NonFungibleToken.NFT) {
      let myToken <- token as! @Chapter2Bikes.NFT
      emit Deposit(id: myToken.id, to: self.owner?.address)
      self.ownedNFTs[myToken.id] <-! myToken
    }

    // Get IDs array
    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    // Borrow reference to NFT: read id
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
    }

    // Borrow reference to NFT: read all data
    pub fun borrowEntireNFT(id: UInt64): &Chapter2Bikes.NFT? {
      if self.ownedNFTs[id] != nil {
        let reference = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return reference as! &Chapter2Bikes.NFT
      } else {
        return nil
      }
    }

    // Collection initialization
    init() {
      self.ownedNFTs <- {}
    }

    destroy() {
      destroy self.ownedNFTs 
    }
  }

  // Admin Resource
  pub resource Admin {
    // mint Chapter2 NFT
    pub fun mint(recipient: &{NonFungibleToken.CollectionPublic}, edition: UInt8, metadata: {String: String}) {
        var newNFT <- create NFT(_edition: edition, _metadata: metadata)

        recipient.deposit(token: <- newNFT)
    }

    // batch mint Chapter2 NFT
    pub fun batchMint(recipient: &{NonFungibleToken.CollectionPublic}, edition: UInt8, metadataArray: [{String: String}]) {
        var i: Int = 0
        while i < metadataArray.length {
            self.mint(recipient: recipient, edition: edition, metadata: metadataArray[i])
            i = i + 1;
        }
    }

    pub fun createNewAdmin(): @Admin {
        return <- create Admin()
    }
  }

  // Contract Level Function Defenitions

  // Public function to create an empty collection
  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }

  // Map edition type to string
  pub fun editionString(_ edition: Edition): String {
    switch edition {
      case Edition.frame:
        return "Frame"
      case Edition.painting:
        return "Painting"
    }
    return ""
  }

  // Contract initialization
  init() {
    // Set named paths
      self.CollectionStoragePath = /storage/Chapter2BikesCollection
      self.CollectionPublicPath = /public/Chapter2BikesCollection
      self.AdminStoragePath = /storage/Chapter2BikesAdmin
      self.AdminPrivatePath = /private/Chapter2BikesAdminUpgrade

      self.totalSupply = 0
      self.frameEditionSupply = 0
      self.paintingEditionSupply = 0

      // Create admin resource and save it to storage
      self.account.save(<-create Admin(), to: self.AdminStoragePath)

      self.account.link<&Chapter2Bikes.Admin>(self.AdminPrivatePath, target: self.AdminStoragePath) ?? panic("Could not get Admin capability")
  }

}