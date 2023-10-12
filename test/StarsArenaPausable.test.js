const hardhat = require('hardhat');

describe('StarsArenaPausable', () => {
  let saCF;
  let saProxy;

  let alice;
  let bob;

  before(async () => {
    saCF = await hardhat.ethers.getContractFactory('StarsArena');
    const signers = await hardhat.ethers.getSigners();
    alice = signers[1];
    bob = signers[2];
  });

  beforeEach(async () => {
    saProxy = await hardhat.upgrades.deployProxy(saCF, [], {
      initializer: 'reinitialize'
    });
    await saProxy.deployed();
  });

  const checkPaused = async (callable, shouldBePaused) => {
    try {
      await callable();
    } catch(e) {
      if (e.message.indexOf('Contract is paused') > 0) {
        if (!shouldBePaused) {
          throw new Error('Error');
        }
      } else {
        throw new Error('Error: something is broken');
      }
      return;
    }
    if (shouldBePaused) {
      throw new Error('Error');
    }
  };

  describe('PausableOrNot', () => {
    it('should not allow to call buy shares on paused state', async () => {
      await checkPaused(async () => {
        await saProxy.connect(alice).buyShares(bob.address, 1);
      }, true);
    });
    it('should not allow to call sell shares on paused state', async () => {
      await checkPaused(async () => {
        await saProxy.connect(alice).sellShares(bob.address, 1);
      }, true);
    });
    it('should allow to call buy & sell shares on non-paused state', async () => {
      await saProxy.setPaused(false);
      await saProxy.connect(alice).buyShares(bob.address, 1, {
        value: await saProxy.connect(alice).getBuyPriceAfterFee(bob.address, 1),
      });
      await checkPaused(async () => {
        await saProxy.connect(alice).sellShares(bob.address, 1);
      }, false);
      await saProxy.setPaused(true);
    });
  });
});
