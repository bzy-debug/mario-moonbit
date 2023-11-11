enum Dir1d {
  Left
  Right
}

enum Dir2d {
  North
  South
  East
  West
}

fn op_equal(self : Dir1d, optb : Dir1d) -> Bool {
  match (self, optb) {
    (Left, Left) | (Right, Right) => true
    _ => false
  }
}

fn op_equal(self : PlayerSize, optb : PlayerSize) -> Bool {
  match (self, optb) {
    (Small, Small) | (Large, Large) => true
    _ => false
  }
}

struct XY {
  mut x : Double
  mut y : Double
}

enum Control {
  Left
  Right
  Up
  Down
}

enum PlayerSize {
  Small
  Large
}

enum Item {
  Mushroom
  FireFlower
  Star
  Coin
}

enum Enemy {
  Goomba
  GKoopa
  RKoopa
  GKoopaShell
  RKoopaShell
}

enum Block {
  QBlock(Item)
  QBlockUsed
  Brick
  UnBBlock
  Cloud
  Panel
  Ground
}

enum Player {
  Standing
  Jumping
  Running
  Crouching
}

enum Part {
  GoombaSquish
  BrickChunkL
  BrickChunkR
  Score100
  Score200
  Score400
  Score800
  Score1000
  Score2000
  Score4000
  Score8000
}

enum Spawn {
  Player(PlayerSize, Player)
  Enemy(Enemy)
  Item(Item)
  Block(Block)
}

