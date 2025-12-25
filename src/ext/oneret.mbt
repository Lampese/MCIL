///|
pub fn oneret(f : @cil.FunDec) -> Unit {
  let ret_typ = match f.svar.vtype {
    @cil.TFun(rt, _, _, _) => rt
    _ => @cil.TVoid([])
  }
  let has_ret = match @cil.unroll_type(ret_typ) {
    @cil.TVoid(_) => false
    _ => true
  }
  let ret_var : Ref[@cil.VarInfo?] = Ref::new(None)
  let have_goto : Ref[Bool] = Ref::new(false)
  let last_loc : Ref[@cil.Location] = Ref::new(@cil.unknown_loc)
  let ret_stmt : Ref[@cil.Stmt?] = Ref::new(None)
  letrec get_ret_var = fn() {
    match ret_var.val {
      Some(rv) => rv
      None => {
        let rv = @cil.make_temp_var(f, "__retres", ret_typ)
        ret_var.val = Some(rv)
        rv
      }
    }
  }
  and get_ret_stmt = fn() -> @cil.Stmt {
    match ret_stmt.val {
      Some(rs) => rs
      None => {
        let rv = if has_ret {
          Some(
            @cil.Lval(@cil.LVal::{
              host: @cil.LHost::Var(get_ret_var()),
              offset: @cil.Offset::NoOffset,
            }),
          )
        } else {
          None
        }
        let rs = @cil.mk_stmt(@cil.Return(rv, last_loc.val))
        ret_stmt.val = Some(rs)
        rs
      }
    }
  }
  and scan_stmts = fn(mainbody : Bool, stmts : Array[@cil.Stmt]) {
    if stmts.is_empty() {
      if mainbody {
        let rs = get_ret_stmt()
        if have_goto.val {
          rs.labels.push(@cil.Label::Label("return_label", last_loc.val, false))
        }
        [rs]
      } else {
        []
      }
    } else {
      let result : Array[@cil.Stmt] = []
      for i, s in stmts {
        match s.skind {
          @cil.Return(retval, loc) => {
            last_loc.val = loc
            if has_ret && retval is None {
              abort("Found return without value in function \{f.svar.vname}")
            }
            if not(has_ret) && retval is Some(_) {
              abort("Found return value in void function \{f.svar.vname}")
            }
            s.skind = match retval {
              Some(rval) =>
                @cil.Instr([
                  @cil.Set(
                    @cil.LVal::{
                      host: @cil.LHost::Var(get_ret_var()),
                      offset: @cil.Offset::NoOffset,
                    },
                    rval,
                    loc,
                  ),
                ])
              None => @cil.Instr([])
            }
            result.push(s)
            if mainbody && i == stmts.length() - 1 {
              ()
            } else {
              let sg = @cil.mk_stmt(@cil.Goto(get_ret_stmt(), loc))
              have_goto.val = true
              result.push(sg)
            }
          }
          @cil.If(cond, then_block, else_block, loc) => {
            s.skind = @cil.If(
              cond,
              scan_block(false, then_block),
              scan_block(false, else_block),
              loc,
            )
            result.push(s)
          }
          @cil.Loop(body, loc, cont_lbl, brk_lbl) => {
            s.skind = @cil.Loop(scan_block(false, body), loc, cont_lbl, brk_lbl)
            result.push(s)
          }
          @cil.Switch(cond, body, cases, loc) => {
            s.skind = @cil.Switch(cond, scan_block(false, body), cases, loc)
            result.push(s)
          }
          @cil.Block(b) => {
            s.skind = @cil.Block(scan_block(false, b))
            result.push(s)
          }
          _ => result.push(s)
        }
      }
      if mainbody && result.length() > 0 {
        let last = result[result.length() - 1]
        match last.skind {
          @cil.Return(_, _) => ()
          _ => {
            let rs = get_ret_stmt()
            if have_goto.val {
              rs.labels.push(
                @cil.Label::Label("return_label", last_loc.val, false),
              )
            }
            result.push(rs)
          }
        }
      }
      result
    }
  }
  and scan_block = fn(mainbody : Bool, b : @cil.Block) -> @cil.Block {
    @cil.Block::{ battrs: b.battrs, bstmts: scan_stmts(mainbody, b.bstmts) }
  }

  f.sbody = scan_block(true, f.sbody)
}

///|
pub fn oneret_file(file : @cil.File) -> Unit {
  @cil.iter_globals(file, fn(g) {
    match g {
      @cil.GFun(fd, _) => oneret(fd)
      _ => ()
    }
  })
}
