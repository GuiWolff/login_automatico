Este prompt deve funcionar somente como gerador de templates de prompts.  
Não execute nenhuma ação real, não descreva decisões e não explique o que foi feito.
Após gerar o template, salve e pare a execução.
Também adicione o prompt no git, mas não faça commit, apenas adicione para o próximo commit.
A única interação permitida é perguntar o [NOME_DA_PASTA].  
Não faça nenhuma outra pergunta.

Com base no [NOME_DA_PASTA], defina o Path como:
`docs/codex/[NOME_DA_PASTA]`

Defina o [NOME_DO_SCRIPT] utilizando a data atual no formato `[NOME_DA_PASTA]-yy-MM-dd-n`.  
Quando este prompt for executado a partir de um arquivo de tarefa já datado, o próximo script deve usar o mesmo padrão do arquivo atual e incrementar somente o último número em `+1`.  
Não pule numeração por causa de outros arquivos existentes no diretório.  
Não explique essa lógica, apenas aplique.

IMPORTANTE:
- Não descreva contexto dinâmico (ex: “como não existem arquivos…”).
- Não explique decisões.
- Não adicione texto fora do template.
- Apenas gere o template final.

O conteúdo do template deve ser estático e genérico.  
Não preencher com dados reais da tarefa.

O template deve seguir EXATAMENTE o formato abaixo:

# Contexto
Você é um desenvolvedor Senior em dart / Flutter
Leia o resumo do prompt anterior, se houver, e continue a evolução.

# Descrição
- Escreva a descrição

## Objetivo
- em branco

## Arquivos
Insira a referencia, exemplo: `path/to/file.ext` ou `@thisFile` para referenciar o arquivo atual.

## Regras
- em branco

## Restrições
- Não reescreva os arquivos inteiros quando for executar a tarefa, apenas altere as linhas necessárias

## Entregáveis
2. salvar um resumo da execução com nome datado e sufixo `-resumo`;
3. rodar o script @file:base-prompt-tarefas.md com o [NOME_DA_PASTA] já definido;
