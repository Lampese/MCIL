///|
pub struct MergeConflict {
  message : String
  loc1 : Location
  loc2 : Location
}

///|
pub struct MergeOptions {
  ignore_conflicts : Bool
  merge_inlines : Bool
  merge_synonyms : Bool
}

///|
pub fn MergeOptions::default() -> MergeOptions {
  { ignore_conflicts: false, merge_inlines: true, merge_synonyms: true }
}

///|
priv struct MergeContext {
  type_map : Map[String, TypeInfo]
  comp_map : Map[Int, CompInfo]
  enum_map : Map[String, EnumInfo]
  var_map : Map[Int, VarInfo]
  conflicts : Array[MergeConflict]
  options : MergeOptions
}

///|
fn MergeContext::new(options : MergeOptions) -> MergeContext {
  {
    type_map: Map::new(),
    comp_map: Map::new(),
    enum_map: Map::new(),
    var_map: Map::new(),
    conflicts: [],
    options,
  }
}

///|
fn add_conflict(
  ctx : MergeContext,
  msg : String,
  loc1 : Location,
  loc2 : Location,
) -> Unit {
  ctx.conflicts.push({ message: msg, loc1, loc2 })
}

///|
fn types_compatible(t1 : Typ, t2 : Typ) -> Bool {
  match (t1, t2) {
    (TVoid(_), TVoid(_)) => true
    (TInt(ik1, _), TInt(ik2, _)) => ik1 == ik2
    (TFloat(fk1, _), TFloat(fk2, _)) => fk1 == fk2
    (TPtr(inner1, _), TPtr(inner2, _)) => types_compatible(inner1, inner2)
    (TArray(elem1, _, _), TArray(elem2, _, _)) => types_compatible(elem1, elem2)
    (TFun(ret1, _, _, _), TFun(ret2, _, _, _)) => types_compatible(ret1, ret2)
    (TComp(ci1, _), TComp(ci2, _)) =>
      ci1.cname == ci2.cname && ci1.cstruct == ci2.cstruct
    (TEnum(ei1, _), TEnum(ei2, _)) => ei1.ename == ei2.ename
    (TNamed(ti1, _), TNamed(ti2, _)) => ti1.tname == ti2.tname
    (TBuiltinVaList(_), TBuiltinVaList(_)) => true
    _ => false
  }
}

///|
fn merge_typedef(ctx : MergeContext, ti : TypeInfo, loc : Location) -> TypeInfo {
  match ctx.type_map.get(ti.tname) {
    Some(existing) => {
      if not(types_compatible(existing.ttype, ti.ttype)) &&
        not(ctx.options.ignore_conflicts) {
        add_conflict(
          ctx,
          "Conflicting typedef for \{ti.tname}",
          loc,
          unknown_loc,
        )
      }
      existing
    }
    None => {
      ctx.type_map.set(ti.tname, ti)
      ti
    }
  }
}

///|
fn merge_comp(ctx : MergeContext, ci : CompInfo, loc : Location) -> CompInfo {
  match ctx.comp_map.get(ci.ckey) {
    Some(existing) => {
      if existing.cfields.length() != ci.cfields.length() &&
        not(ctx.options.ignore_conflicts) {
        add_conflict(
          ctx,
          "Conflicting fields for \{ci.cname}",
          loc,
          unknown_loc,
        )
      }
      existing
    }
    None => {
      ctx.comp_map.set(ci.ckey, ci)
      ci
    }
  }
}

///|
fn merge_enum(ctx : MergeContext, ei : EnumInfo, loc : Location) -> EnumInfo {
  match ctx.enum_map.get(ei.ename) {
    Some(existing) => {
      if existing.eitems.length() != ei.eitems.length() &&
        not(ctx.options.ignore_conflicts) {
        add_conflict(
          ctx,
          "Conflicting enum items for \{ei.ename}",
          loc,
          unknown_loc,
        )
      }
      existing
    }
    None => {
      ctx.enum_map.set(ei.ename, ei)
      ei
    }
  }
}

///|
fn merge_var(ctx : MergeContext, vi : VarInfo, loc : Location) -> VarInfo {
  match ctx.var_map.get(vi.vid) {
    Some(existing) => {
      if not(types_compatible(existing.vtype, vi.vtype)) &&
        not(ctx.options.ignore_conflicts) {
        add_conflict(
          ctx,
          "Conflicting types for variable \{vi.vname}",
          loc,
          unknown_loc,
        )
      }
      existing
    }
    None => {
      ctx.var_map.set(vi.vid, vi)
      vi
    }
  }
}

///|
fn merge_global(
  ctx : MergeContext,
  result : Array[Global],
  g : Global,
  seen_defs : @hashset.HashSet[String],
) -> Unit {
  match g {
    GType(ti, loc) => {
      let merged = merge_typedef(ctx, ti, loc)
      if not(seen_defs.contains("type:" + merged.tname)) {
        seen_defs.add("type:" + merged.tname)
        result.push(GType(merged, loc))
      }
    }
    GCompTag(ci, loc) => {
      let merged = merge_comp(ctx, ci, loc)
      let key = "comp:" + merged.ckey.to_string()
      if not(seen_defs.contains(key)) {
        seen_defs.add(key)
        result.push(GCompTag(merged, loc))
      }
    }
    GCompTagDecl(ci, loc) => {
      let merged = merge_comp(ctx, ci, loc)
      let key = "comp_decl:" + merged.ckey.to_string()
      if not(seen_defs.contains(key)) &&
        not(seen_defs.contains("comp:" + merged.ckey.to_string())) {
        seen_defs.add(key)
        result.push(GCompTagDecl(merged, loc))
      }
    }
    GEnumTag(ei, loc) => {
      let merged = merge_enum(ctx, ei, loc)
      let key = "enum:" + merged.ename
      if not(seen_defs.contains(key)) {
        seen_defs.add(key)
        result.push(GEnumTag(merged, loc))
      }
    }
    GEnumTagDecl(ei, loc) => {
      let merged = merge_enum(ctx, ei, loc)
      let key = "enum_decl:" + merged.ename
      if not(seen_defs.contains(key)) &&
        not(seen_defs.contains("enum:" + merged.ename)) {
        seen_defs.add(key)
        result.push(GEnumTagDecl(merged, loc))
      }
    }
    GVarDecl(vi, loc) => {
      let merged = merge_var(ctx, vi, loc)
      let key = "var_decl:" + merged.vname
      if not(seen_defs.contains(key)) &&
        not(seen_defs.contains("var:" + merged.vname)) {
        seen_defs.add(key)
        result.push(GVarDecl(merged, loc))
      }
    }
    GVar(vi, init_info, loc) => {
      let merged = merge_var(ctx, vi, loc)
      let key = "var:" + merged.vname
      if not(seen_defs.contains(key)) {
        seen_defs.add(key)
        result.push(GVar(merged, init_info, loc))
      }
    }
    GFun(fd, loc) => {
      let merged_var = merge_var(ctx, fd.svar, loc)
      let key = "fun:" + merged_var.vname
      if not(seen_defs.contains(key)) {
        seen_defs.add(key)
        let merged_fd : FunDec = { ..fd, svar: merged_var }
        result.push(GFun(merged_fd, loc))
      } else if ctx.options.merge_inlines && fd.svar.vinline {
        ()
      }
    }
    GAsm(s, loc) => result.push(GAsm(s, loc))
    GPragma(attr, loc) => result.push(GPragma(attr, loc))
    GText(s) => result.push(GText(s))
  }
}

///|
pub fn merge(
  files : Array[File],
  output_name : String,
  options : MergeOptions,
) -> (File, Array[MergeConflict]) {
  let ctx = MergeContext::new(options)
  let result_globals : Array[Global] = []
  let seen_defs = @hashset.new()
  for file in files {
    for g in file.globals {
      merge_global(ctx, result_globals, g, seen_defs)
    }
  }
  let result : File = {
    filename: output_name,
    globals: result_globals,
    globinit: None,
    globinitcalled: false,
  }
  (result, ctx.conflicts)
}

///|
pub fn merge_files(files : Array[File], output_name : String) -> File {
  let (result, _) = merge(files, output_name, MergeOptions::default())
  result
}
