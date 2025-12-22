import 'package:dartz/dartz.dart';
import 'failure.dart';

abstract class UseCase<Output, Params> {
  Future<Either<Failure, Output>> call(Params params);
}

class NoParams {}
