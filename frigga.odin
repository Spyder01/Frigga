package frigga

import "core:strings"
import "core:os"
import "core:fmt"

ArgType :: distinct enum {BOOL, STRING, DEFAULT}
ArgValueType :: distinct union {bool, string}
DEFAULT_FLAG := ""


Arg :: struct {
    name: string,
    annotation: string,
    secondary_annotaion: string, 
    type: ArgType,
    required: bool,
    default: ArgValueType,
    help: string
}


InvalidArgError :: struct {
    name: string
}

NoValueArgError :: struct {
    name: string
}

ArgNotFound :: struct {
    name: string
}

MultipleDefaultError :: struct {}

ArgParseError :: union {
    InvalidArgError, NoValueArgError, ArgNotFound, MultipleDefaultError
}

get_error_message :: proc (err: ArgParseError) -> string {
    string_builder: strings.Builder
    switch e in err {
        case InvalidArgError:
            return fmt.sbprintf(&string_builder, "Invalid arguement %s", e.name)
        case NoValueArgError: 
            return fmt.sbprintf(&string_builder, "No value for the arguement %s", e.name)
        case ArgNotFound: 
            return fmt.sbprintf(&string_builder, "Arguement %s not found.", e.name)
        case MultipleDefaultError: 
            return fmt.sbprintf(&string_builder, "Defining multiple parameters is not aloowed.")
    }

    return ""
}


parse :: proc (args: []Arg, args_raw_: []string = nil) -> (map[string]ArgValueType, ArgParseError) {
    args_raw: []string;

    if args_raw_ == nil {
        args_raw = os.args[1:];
    } 
    else {
        args_raw = args_raw_
    }


    values := make(map[string]ArgValueType)
    curr_arg := ""
    obtained_default := false
    default_arg: Arg

    for arg_raw in args_raw {
        found := false

        if curr_arg != "" {
            values[curr_arg] = arg_raw
            curr_arg = ""    
            continue
        }

        for arg in args {
            match := arg_raw == arg.annotation || arg_raw == arg.secondary_annotaion

                switch arg.type {
                    
                    case ArgType.STRING:
                        if match {
                            curr_arg = arg.name
                            found = true
                        }
                    case ArgType.BOOL: 
                        if match {
                            values[arg.name] = true
                            curr_arg = ""
                            found = true
                        }
                    case ArgType.DEFAULT:
                        if obtained_default && arg != default_arg {
                            return nil, MultipleDefaultError{}
                        }

                        default_arg = arg
                }
            }

        if !found {
            if obtained_default || curr_arg != "" || default_arg.name == "" {
                return nil, InvalidArgError{arg_raw}
            }
            
            values[default_arg.name] = arg_raw
            obtained_default = true
        }
    }

    arg_not_found_err := check_arg_not_found(args, &values)

    if arg_not_found_err.name != "" {
        return nil, arg_not_found_err
    }

    if curr_arg != "" {
        return nil, NoValueArgError{curr_arg}
    }

    return values, nil
}

check_arg_not_found :: proc (args: []Arg, values: ^map[string]ArgValueType) ->  ArgNotFound {

    for arg in args {
        _, found := values[arg.name]
        if !arg.required || found {
            continue
        }
        
        if arg.default != nil {
            values[arg.name] = arg.default
            continue
        }

        annotation := arg.type == ArgType.DEFAULT ? arg.name : arg.annotation
        return ArgNotFound{annotation}
    }
    return ArgNotFound{}
}


define_arg :: proc (name: string, flag: string, secondary_flag: string = "", arg_type: ArgType = ArgType.STRING, required: bool = false, default_val: ArgValueType = nil, help: string = "") -> Arg {
    return Arg {name, flag, secondary_flag, arg_type, required, default_val, help}
}
