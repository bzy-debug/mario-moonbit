// (* Represents the values of relevant key bindings. *)
struct Keys {
  mut left : Bool
  mut right : Bool
  mut up : Bool
  mut down : Bool
  mut bbox : Int
}

struct St {
  bgd : Sprite
  mut vpt : Viewport
  map : Double
  mut score : Int
  mut coins : Int
  mut multiplier : Int
  mut game_over : Bool
}

// (*pressed_keys instantiates the keys.*)

let pressed_keys : Ref[Keys] = Ref::make(
  { left: false, right: false, up: false, down: false, bbox: 0 },
)

let collid_objs : Ref[List[Collidable]] = Ref::make(List::Nil) // (* List of next iteration collidable objects *)

let particles : Ref[List[Particle]] = Ref::make(List::Nil) // (* List of next iteration particles *)

let last_time : Ref[Double] = Ref::make(-16.6) // (* Used for calculating fps *)

// (* Calculates fps as the difference between [t0] and [t1] *)

fn calc_fps(t0 : Double, t1 : Double) -> Double {
  let delta = (t1 - t0) / 1000.0
  1.0 / delta
}

// (* Adds [i] to the score in [state] *)
fn update_score(state : St, i : Int) {
  state.score = state.score + i
}

fn player_attack_enemy(o1 : Object, typ : Enemy, s2 : Sprite,
        o2 : Object, state : St) -> (Option[Collidable], Option[Collidable]) {
  o1.invuln = 10
  o1.jumping = false
  o1.grounded = true
  match typ {
    GKoopaShell | RKoopaShell => {
      let r2 = evolve_enemy(o1.dir, typ, s2, o2)
      o1.vel.y = -dampen_jump
      o1.pos.y = o1.pos.y - 5.0
      (None, r2)
    }
    _ => {
      dec_health(o2)
      o1.vel.y = -dampen_jump
      if state.multiplier == 8 {
        update_score(state, 800)
        o2.score = 800
        (None, evolve_enemy(o1.dir, typ, s2, o2))
      } else {
        let score = 100 * state.multiplier
        update_score(state, score)
        o2.score = score
        state.multiplier = state.multiplier * 2
        (None, evolve_enemy(o1.dir, typ, s2, o2))
      }
    }
  }
}

// (*enemy_attack_player is used when an enemy kills a player.*)
fn enemy_attack_player( o1 : Object, t2 : Enemy, s2 : Sprite,
        o2 : Object) -> (Option[Collidable], Option[Collidable]) {
  match t2 {
    GKoopaShell | RKoopaShell => {
      let r2 = if o2.vel.x == 0.0 {
        evolve_enemy(o1.dir, t2, s2, o2)
      } else {
        dec_health(o1)
        o1.invuln = invuln
        None
      }
      (None, r2)
    }
    _ => {
      dec_health(o1)
      o1.invuln = invuln
      (None, None)
    }
  }
}

// (*In the case that two enemies collide, they are to reverse directions. However,
// *in the case that one or more of the two enemies is a koopa shell, then
// *the koopa shell kills the other enemy. *)
fn col_enemy_enemy(t1 : Enemy, s1 : Sprite, o1 : Object, t2 : Enemy, s2 : Sprite,
        o2 : Object, dir : Dir2d) -> (Option[Collidable], Option[Collidable]) {
  match (t1, t2) {
    (GKoopaShell, GKoopaShell) | (GKoopaShell, RKoopaShell) => {
      dec_health(o1)
      dec_health(o2)
      (None, None)
    }
    (RKoopaShell, RKoopaShell) | (RKoopaShell, GKoopaShell) => {
      dec_health(o1)
      dec_health(o2)
      (None, None)
    }
    (RKoopaShell, _) | (GKoopaShell, _) => if o1.vel.x == 0.0 {
      rev_dir(o2, t2, s2)
      (None, None)
    } else {
      dec_health(o2)
      (None, None)
    }
    (_, RKoopaShell) | (_, GKoopaShell) => if o2.vel.x == 0.0 {
      rev_dir(o1, t1, s1)
      (None, None)
    } else {
      dec_health(o1)
      (None, None)
    }
    _ => match dir {
      West | East => {
        rev_dir(o1, t1, s1)
        rev_dir(o2, t2, s2)
        (None, None)
      }
      _ => (None, None)
    }
  }
}

// (* Run the broad phase object filtering *)
fn broad_phase(collid : Collidable, all_collids : List[Collidable], state : St) ->
     List[Collidable] {
  let obj = get_obj(collid)
  all_collids.filter(
    fn(_c) {
      in_viewport(state.vpt, obj.pos) || is_player(collid) || out_of_viewport_below(
        state.vpt,
        obj.pos.y,
      )
    },
  )
}

// (*narrow_phase of collision is used in order to continuously loop through
// *each of the collidable objects to constantly check if collisions are
// *occurring.*)
fn narrow_phase(c : Collidable, cs : List[Collidable], state : St) ->
     List[Collidable] {
  fn narrow_helper(c : Collidable, cs : List[Collidable], state : St,
          acc : List[Collidable]) -> List[Collidable] {
    match cs {
      Nil => acc
      Cons(h, t) => {
        let c_obj = get_obj(c)
        let new_objs = if c != h {
          match check_collision(c, h) {
            None => (Option::None, Option::None)
            Some(dir) => if get_obj(h).id != c_obj.id {
              process_collision(dir, c, h, state)
            } else {
              (None, None)
            }
          }
        } else {
          (None, None)
        }
        let acc = match new_objs {
          (None, Some(o)) => List::Cons(o, acc)
          (Some(o), None) => List::Cons(o, acc)
          (Some(o1), Some(o2)) => Cons(o1, Cons(o2, acc))
          (None, None) => acc
        }
        narrow_helper(c, t, state, acc)
      }
    }
  }

  narrow_helper(c, cs, state, Nil)
}

// (* This is an optimization setp to determine which objects require narrow phase
// * checking. This excludes static collidables, allowing collision to only be
// * checked with moving objects. This method is called once per collidable.
// * Collision detection proceeds as follows:
// * 1. Broad phase - filter collidables that cannot possibly collide with
// *    this object.
// * 2. Narrow phase - compare against all objects to determine whether there
// *    is a collision, and process the collision.
// * This method returns a list of objects that are created, which should be
// * added to the list of collidables for the next iteration.
// * *)
fn check_collisions(collid : Collidable, all_collids : List[Collidable],
        state : St) -> List[Collidable] {
  match collid {
    Block(_, _, _) => Nil
    _ => {
      let broad = broad_phase(collid, all_collids, state)
      narrow_phase(collid, broad, state)
    }
  }
}

// (* Returns whether the bounding box should be drawn *)
fn check_bbox_enabled() -> Bool {
  pressed_keys.value.bbox == 1
}

// (* update_collidable is the primary update method for collidable objects,
// * checking the collision, updating the object, and drawing to the canvas.*)
fn update_collidable(state : St, collid : Collidable,
        all_collids : List[Collidable]) -> List[Collidable] {
  let obj = get_obj(collid)
  let spr = get_sprite(collid)
  obj.invuln = if obj.invuln > 0 {
    obj.invuln - 1
  } else {
    0
  }
  // (* Prevent position from being updated outside of viewport *)
  let viewport_filter = in_viewport(state.vpt, obj.pos) || is_player(collid) || out_of_viewport_below(
      state.vpt,
      obj.pos.y,
    )
  if not(obj.kill) && viewport_filter {
    obj.grounded = false
    process_obj(obj, state.map)
    // (* Run collision detection if moving object*)
    let evolved = check_collisions(collid, all_collids, state)
    // (* Render and update animation *)
    let vpt_adj_xy = coord_to_viewport(state.vpt, obj.pos)
    render(spr, vpt_adj_xy.x, vpt_adj_xy.y)
    if check_bbox_enabled() {
      render_box(spr, vpt_adj_xy.x, vpt_adj_xy.y)
    }
    if obj.vel.x != 0.0 || not(is_enemy(collid)) {
      update_animation(spr)
    }
    evolved
  } else {
    Nil
  }
}

// (* Converts a keypress to a list of control keys, allowing more than one key
// * to be processed each frame. *)
fn translate_keys() -> List[Control] {
  var res = List::Nil
  if pressed_keys.value.left {
    res = List::Cons(Control::Left, res)
  }
  if pressed_keys.value.right {
    res = List::Cons(Control::Right, res)
  }
  if pressed_keys.value.up {
    res = List::Cons(Control::Up, res)
  }
  if pressed_keys.value.down {
    res = List::Cons(Control::Down, res)
  }
  res
}

// (* run_update is used to update all of the collidables at once. Primarily used
// * as a wrapper method. This method is necessary to differentiate between
// * the player collidable and the remaining collidables, as special operations
// * such as viewport centering only occur with the player.*)
fn run_update_collid(state : St, collid : Collidable,
        all_collids : List[Collidable]) -> Collidable {
  match collid {
    Player(_, s, o) as p => {
      let keys = translate_keys()
      o.crouch = false
      let player = match update_player(o, keys) {
        None => p
        Some(new_typ, new_spr) => {
          normalize_pos(o.pos, s.params, new_spr.params)
          Player(new_typ, new_spr, o)
        }
      }
      let evolved = update_collidable(state, player, all_collids)
      collid_objs.value = collid_objs.value.concat(evolved)
      player
    }
    _ => {
      let obj = get_obj(collid)
      let evolved = update_collidable(state, collid, all_collids)
      if not(obj.kill) {
        collid_objs.value = List::Cons(
          collid,
          collid_objs.value.concat(evolved),
        )
      }
      let new_parts = if obj.kill {
        kill(collid)
      } else {
        List::Nil
      }
      particles.value = particles.value.concat(new_parts)
      collid
    }
  }
}

// (* Primary update function to update and persist a particle *)
fn run_update_particle(state : St, part : Particle) {
  process(part)
  let x = part.pos.x - state.vpt.pos.x
  let y = part.pos.y - state.vpt.pos.y
  render(part.params.sprite, x, y)
  if not(part.kill) {
    particles.value = List::Cons(part, particles.value)
  }
}

fn update_helper(time : Double, state : St, objs : List[Collidable],
        parts : List[Particle]) {
  if state.game_over == true {
    game_win()
  } else {
    collid_objs.value = List::Nil
    particles.value = List::Nil
    let fps_ = calc_fps(last_time.value, time).to_int()
    last_time.value = time
    clear_canvas()

    // (* Parallax background *)
    let vpos_x_int = (state.vpt.pos.x / 5.0).to_int()
    let bgd_width = state.bgd.params.frame_size.0.to_int()
    draw_bgd(state.bgd, (vpos_x_int % bgd_width).to_double())
    players.value = players.value.map(fn(p) { run_update_collid(state, p, objs) })
    if players.value.any(fn(p) {get_obj(p).kill}) {
      game_lose()
    } else {
      state.vpt = update(state.vpt, get_obj(players.value.at(0)).pos)
      _ := objs.map(fn(obj) { run_update_collid(state, obj, objs) })
      _ := parts.map(fn(part) { run_update_particle(state, part) })
      fps(fps_)
      hud(state.score, state.coins)
    }
  }
}

pub fn game_update(t : Double) {
  update_helper(t, state, collid_objs.value, particles.value)
}

pub fn keydown_up() {
  pressed_keys.value.up = true
}

pub fn keydown_down() {
  pressed_keys.value.down = true
}

pub fn keydown_left() {
  pressed_keys.value.left = true
}

pub fn keydown_right() {
  pressed_keys.value.right = true
}

pub fn keydown_B() {
  pressed_keys.value.bbox = pressed_keys.value.bbox.lxor(1)
}

pub fn keyup_up() {
  pressed_keys.value.up = false
}

pub fn keyup_down() {
  pressed_keys.value.down = false
}

pub fn keyup_left() {
  pressed_keys.value.left = false
}

pub fn keyup_right() {
  pressed_keys.value.right = false
}

// (* Keydown event handler translates a key press *)
// fn keydown(evt)=
// let evt = Dom_html.keyboardEventToJsObj evt in
// let () = match evt##keyCode with
// | 38 | 32 | 87 -> pressed_keys.up <- true
// | 39 | 68 -> pressed_keys.right <- true
// | 37 | 65 -> pressed_keys.left <- true
// | 40 | 83 -> pressed_keys.down <- true
// | 66 -> pressed_keys.bbox <- (pressed_keys.bbox + 1) mod 2
// | _ -> ()
// in Js.true_

// (* Keyup event handler translates a key release *)
// let keyup evt =
// let evt = Dom_html.keyboardEventToJsObj evt in
// let () = match evt##keyCode with
// | 38 | 32 | 87 -> pressed_keys.up <- false
// | 39 | 68 -> pressed_keys.right <- false
// | 37 | 65 -> pressed_keys.left <- false
// | 40 | 83 -> pressed_keys.down <- false
// | _ -> ()
// in Js.true_
