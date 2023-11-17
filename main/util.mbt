fn min[T : Compare](a : T, b : T) -> T {
  if a < b {
    a
  } else {
    b
  }
}

fn max[T : Compare](a : T, b : T) -> T {
  if a < b {
    b
  } else {
    a
  }
}

fn abs(self : Double) -> Double {
  if self < 0.0 {
    -self
  } else {
    self
  }
}

struct Ref[T] {
  mut value : T
}

fn Ref::make[T](value : T) -> Ref[T] {
  { value, }
}

fn filter[T](self : List[T], f : (T) -> Bool) -> List[T] {
  match self {
    Nil => Nil
    Cons(x, xs) => if f(x) {
      Cons(x, xs.filter(f))
    } else {
      xs.filter(f)
    }
  }
}

fn map[T, U](self : List[T], f : (T) -> U) -> List[U] {
  match self {
    Nil => Nil
    Cons(x, xs) => Cons(f(x), map(xs, f))
  }
}

fn tolist[T](self : Array[T]) -> List[T] {
  let len = self.length()
  fn aux(i) {
    if i < len {
      List::Cons(self[i], aux(i + 1))
    } else {
      List::Nil
    }
  }

  aux(0)
}

fn concat[X](self : List[X], ys : List[X]) -> List[X] {
  match self {
    Nil => ys
    Cons(x, rest) => Cons(x, concat(rest, ys))
  }
}

fn any[X](self: List[X], predicate: (X) -> Bool) -> Bool {
  match self {
    Nil => false
    Cons(x, xs) => predicate(x) || any(xs, predicate)
  }
}

fn at[X](self: List[X], index: Int) -> X {
  if index < 0 {
    abort("invalid index")
  }
  fn at_helper(l: List[X], index: Int) -> X {
    match l {
      Nil => abort("invalid index")
      Cons(x, xs) =>
        if index == 0 {
          x
        } else {
          at_helper(xs, index - 1)
        }
    }
  }
  at_helper(self, index)
}