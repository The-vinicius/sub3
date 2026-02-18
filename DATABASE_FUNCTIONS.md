# Funções de Banco de Dados - Sub3

Este documento descreve as funções implementadas para salvar e recuperar objetos `Sub` de um banco de dados SQLite.

## Estrutura do Banco de Dados

A tabela `subs` contém os seguintes campos:
- `id`: Chave primária auto-incrementada
- `name`: Nome do subtitle
- `subPath1`: Caminho do arquivo de subtitle (.srt/.vtt)
- `mp3Path`: Caminho do arquivo de áudio
- `createdAt`: Data de criação (ISO 8601)

## Funções Principais

### 1. Salvar Subtitle (`saveSub`)

```dart
Future<int> saveSub(Sub sub) async
```

**Descrição**: Salva um objeto `Sub` no banco de dados.

**Parâmetros**:
- `sub`: Objeto `Sub` a ser salvo

**Retorno**: ID do registro inserido

**Exemplo**:
```dart
final sub = Sub('Meu Subtitle', File('/path/sub.srt'), File('/path/audio.mp3'));
final id = await DatabaseService.instance.saveSub(sub);
print('Subtitle salvo com ID: $id');
```

### 2. Recuperar Todos os Subtitles (`getAllSubs`)

```dart
Future<List<Sub>> getAllSubs() async
```

**Descrição**: Recupera todos os objetos `Sub` do banco de dados, ordenados por data de criação (mais recentes primeiro).

**Retorno**: Lista de objetos `Sub`

**Exemplo**:
```dart
final subs = await DatabaseService.instance.getAllSubs();
for (final sub in subs) {
  print('${sub.name} (ID: ${sub.id})');
}
```

### 3. Recuperar Subtitle por ID (`getSubById`)

```dart
Future<Sub?> getSubById(int id) async
```

**Descrição**: Recupera um objeto `Sub` específico pelo ID.

**Parâmetros**:
- `id`: ID do subtitle a ser recuperado

**Retorno**: Objeto `Sub` ou `null` se não encontrado

**Exemplo**:
```dart
final sub = await DatabaseService.instance.getSubById(1);
if (sub != null) {
  print('Encontrado: ${sub.name}');
}
```

### 4. Atualizar Subtitle (`updateSub`)

```dart
Future<int> updateSub(int id, Sub sub) async
```

**Descrição**: Atualiza um objeto `Sub` existente no banco de dados.

**Parâmetros**:
- `id`: ID do subtitle a ser atualizado
- `sub`: Objeto `Sub` com os novos dados

**Retorno**: Número de linhas afetadas

**Exemplo**:
```dart
final updatedSub = existingSub.copyWith(name: 'Novo Nome');
await DatabaseService.instance.updateSub(1, updatedSub);
```

### 5. Deletar Subtitle (`deleteSub`)

```dart
Future<int> deleteSub(int id) async
```

**Descrição**: Remove um objeto `Sub` do banco de dados.

**Parâmetros**:
- `id`: ID do subtitle a ser deletado

**Retorno**: Número de linhas afetadas

**Exemplo**:
```dart
await DatabaseService.instance.deleteSub(1);
```

### 6. Deletar Todos os Subtitles (`deleteAllSubs`)

```dart
Future<int> deleteAllSubs() async
```

**Descrição**: Remove todos os objetos `Sub` do banco de dados.

**Retorno**: Número de linhas afetadas

**Exemplo**:
```dart
await DatabaseService.instance.deleteAllSubs();
```

## Uso na Interface

### Salvar Novo Subtitle
1. Clique no botão "+" (FloatingActionButton)
2. Digite o nome do subtitle
3. Selecione o arquivo de subtitle (.srt/.vtt)
4. Selecione o arquivo de áudio
5. Clique em "Save"

### Deletar Subtitle
1. Na lista de subtitles, clique no ícone de lixeira (vermelho)
2. Confirme a exclusão no diálogo

### Limpar Todos os Subtitles
1. Clique no ícone de limpar (na AppBar)
2. Confirme a exclusão no diálogo

## Tratamento de Erros

Todas as funções incluem tratamento de erros e feedback visual:
- **Sucesso**: SnackBar verde com mensagem de confirmação
- **Erro**: SnackBar vermelha com detalhes do erro

## Dependências

As seguintes dependências foram adicionadas ao `pubspec.yaml`:
- `sqflite: ^2.3.3+1` - Para operações de banco de dados SQLite
- `path: ^1.9.0` - Para manipulação de caminhos de arquivo

## Arquivos Criados/Modificados

1. **`lib/app/services/database_service.dart`** - Serviço principal do banco de dados
2. **`lib/app/models/sub.dart`** - Modelo atualizado com métodos `toMap()`, `fromMap()` e `copyWith()`
3. **`lib/app/ui/widgets/card_sub.dart`** - Widget atualizado com botão de deletar
4. **`lib/main.dart`** - Interface principal atualizada para usar o banco de dados
5. **`lib/app/examples/database_example.dart`** - Exemplos de uso das funções
6. **`pubspec.yaml`** - Dependências adicionadas 