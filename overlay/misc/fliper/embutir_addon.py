"""Embute o painel Fliper (misc/fliper/addon/fliper) no editor: gera editor/project_manager/fliper_addon_data.h.
   Todo projeto novo criado na Fliper Engine ganha addons/fliper já ligado.
   python3 misc/fliper/embutir_addon.py   (rode de novo sempre que o addon mudar)"""
import os
AQUI = os.path.dirname(os.path.abspath(__file__)); RAIZ = os.path.dirname(os.path.dirname(AQUI))
ORIGEM = os.path.join(AQUI, 'addon', 'fliper')
linhas = ['/* GERADO por misc/fliper/embutir_addon.py: não edite à mão. */', '#pragma once', '',
          'struct FliperAddonFile {', '\tconst char *path;', '\tconst char *content;', '};', '',
          'static const FliperAddonFile fliper_addon_files[] = {']
for nome in sorted(os.listdir(ORIGEM)):
    t = open(os.path.join(ORIGEM, nome), encoding='utf-8').read()
    assert ')FLP"' not in t
    pedacos = [t[i:i + 3000] for i in range(0, len(t), 3000)] or ['']  # MSVC: limite por literal
    linhas.append(f'\t{{ "addons/fliper/{nome}",')
    linhas += [f'\t\tR"FLP({p})FLP"' for p in pedacos]
    linhas.append('\t},')
linhas += ['};', '', 'static const int fliper_addon_files_count = sizeof(fliper_addon_files) / sizeof(fliper_addon_files[0]);', '']
open(os.path.join(RAIZ, 'editor/project_manager/fliper_addon_data.h'), 'w', encoding='utf-8').write('\n'.join(linhas))
print('addon embutido:', len(os.listdir(ORIGEM)), 'arquivos')
