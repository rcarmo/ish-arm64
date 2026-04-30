if get_option('kernel') == 'ish'
    # these tools are specific to x86_64 linux
    if host_machine.system() == 'linux' and host_machine.cpu() == 'x86_64'
        transplant_src = [
            'vdso-transplant.c',
            'ptutil.c',
        ]
        executable('ptraceomatic', ['ptraceomatic.c', 'undefined-flags.c', transplant_src], dependencies: [ish])
        configure_file(input: 'ptraceomatic-gdb.gdb', output: '@PLAINNAME@', copy: true)

        # tools for messing with vdsos
        # executable('vdso-dump', ['vdso-dump.c'], c_args: ['-m32'], link_args: ['-m32'])
        executable('vdso-transplant', ['vdso-transplant-main.c', transplant_src],
            include_directories: includes)
    endif

    unicorn = cc.find_library('unicorn', required: false)
    if unicorn.found()
        executable('unicornomatic', ['unicornomatic.c', 'undefined-flags.c'], dependencies: [ish, unicorn])
        configure_file(input: 'ptraceomatic-gdb.gdb', output: 'unicornomatic-gdb.gdb', copy: true)
    endif
endif

libarchive = dependency('libarchive', required: false)
if not libarchive.found()
    # homebrew
    libarchive_lib = cc.find_library('archive', dirs: ['/usr/local/opt/libarchive/lib'], required: false)
    if libarchive_lib.found()
        libarchive = declare_dependency(dependencies: [libarchive_lib], include_directories: include_directories(['/usr/local/opt/libarchive/include']))
    else
        # Apple Silicon Homebrew
        libarchive_lib = cc.find_library('archive', dirs: ['/opt/homebrew/opt/libarchive/lib'], required: false)
        if libarchive_lib.found()
            libarchive = declare_dependency(dependencies: [libarchive_lib], include_directories: include_directories(['/opt/homebrew/opt/libarchive/include']))
        endif
    endif
endif

if libarchive.found()
    fakefsify_src = [
        'fakefsify.c',
        'fakefs.c',
        '../util/fchdir.c',
    ]
    fakefsify = executable('fakefsify', fakefsify_src, dependencies: [libarchive], link_with: [libfakefs], include_directories: [includes])
    custom_target('unfakefsify',
        build_by_default: true,
        command: ['ln', '-sf', 'fakefsify', '@OUTPUT@'],
        output: 'unfakefsify')
endif

if host_machine.system() == 'linux'
    sdl2 = dependency('sdl2', required: false)
    sdl2_ttf = dependency('SDL2_ttf', required: false)
    vterm = dependency('vterm', required: false)
    libutil = cc.find_library('util', required: false)
    libvncserver = cc.find_library('vncserver', required: false)
    if sdl2.found() and sdl2_ttf.found() and vterm.found() and libutil.found() and libvncserver.found()
        executable('ish-sdl-vnc', ['ish_sdl_vnc.c'],
            include_directories: includes,
            dependencies: [sdl2, sdl2_ttf, vterm, libutil, libvncserver])
    endif
endif
